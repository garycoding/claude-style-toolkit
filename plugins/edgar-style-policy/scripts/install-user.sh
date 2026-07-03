#!/bin/bash
# SPDX-FileCopyrightText: 2026 Gary Frattarola
# SPDX-License-Identifier: MIT OR Apache-2.0
#
# User-tier installer — NO sudo required. Deploys a staged style policy
# entirely under ~/.claude. Nothing is tamper-resistant at this tier;
# use build-managed-installer.sh for the root-owned variant.
#
# Usage: ./install-user.sh <staging-dir> [style-name]
#   <staging-dir> must contain: canonical.md, digest.sh, review-prompt.txt
#   [style-name]  display name for the output style (default: Writing Style)
#
# JSON work runs on whichever engine the machine has — python3, osascript
# (macOS), or node — via json-tool.sh. Identical behavior on macOS and Linux.
#
# Actions (all idempotent):
#   ~/.claude/writing-style.md            <- canonical.md
#   ~/.claude/CLAUDE.md                   <- append @import line if absent
#   ~/.claude/output-styles/<slug>.md     <- frontmatter + canonical
#   ~/.claude/hooks/style-digest.sh       <- digest hook, chmod +x
#   ~/.claude/settings.json               <- outputStyle + digest command hook
#                                            + judgment-review prompt hook
#                                            (merged; backup written first)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=json-tool.sh
source "${SCRIPT_DIR}/json-tool.sh"

STAGING="${1:?Usage: install-user.sh <staging-dir> [style-name]}"
STYLE_NAME="${2:-Writing Style}"
case "$STYLE_NAME" in
    *$'\n'*) echo "Style name must not contain newlines." >&2; exit 1 ;;
    \"*)     echo "Style name must not start with a quote." >&2; exit 1 ;;
esac
SLUG=$(printf '%s' "$STYLE_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//')
[[ -n "$SLUG" ]] || SLUG="writing-style"

CLAUDE_DIR="${HOME}/.claude"
CANONICAL_SRC="${STAGING}/canonical.md"
SETTINGS="${CLAUDE_DIR}/settings.json"
for f in canonical.md digest.sh review-prompt.txt; do
    [[ -f "${STAGING}/${f}" ]] || { echo "Missing ${STAGING}/${f}" >&2; exit 1; }
done

# Preflight BEFORE any mutation: an engine must exist, and any existing
# settings.json must parse, or we abort cleanly rather than half-install.
ENGINE="$(detect_json_engine)"
if [[ -z "$ENGINE" ]]; then
    echo "No JSON engine found (python3, osascript, or node)." >&2
    echo "On macOS run: xcode-select --install   (or use the skill's model-merge fallback)" >&2
    echo "On Linux run: sudo apt install python3. Nothing has been changed." >&2
    exit 1
fi
if [[ -f "$SETTINGS" ]]; then
    if ! EXISTING="$(cat "$SETTINGS")" || ! EXISTING="$EXISTING" json_transform validate >/dev/null; then
        echo "~/.claude/settings.json is not valid JSON. Fix or remove it, then rerun." >&2
        echo "Nothing has been changed." >&2
        exit 1
    fi
else
    EXISTING=""
fi

# Build the merged settings up front (pure transforms; nothing written yet).
FRAGMENT="$(STYLE="$STYLE_NAME" PROMPT="$(cat "${STAGING}/review-prompt.txt")" json_transform fragment)"
FRAGMENT="${FRAGMENT//__CS_HOOKS_DIR__/${CLAUDE_DIR}/hooks}"
MERGED="$(FRAGMENT="$FRAGMENT" EXISTING="$EXISTING" json_transform merge)"

mkdir -p "${CLAUDE_DIR}/hooks" "${CLAUDE_DIR}/output-styles"

# Canonical copy + import from the global CLAUDE.md (append, never overwrite).
cp "$CANONICAL_SRC" "${CLAUDE_DIR}/writing-style.md"
IMPORT_LINE="@~/.claude/writing-style.md"
touch "${CLAUDE_DIR}/CLAUDE.md"
if ! grep -qxF "$IMPORT_LINE" "${CLAUDE_DIR}/CLAUDE.md"; then
    printf '\n%s\n' "$IMPORT_LINE" >> "${CLAUDE_DIR}/CLAUDE.md"
    echo "Added import line to ~/.claude/CLAUDE.md"
fi

# Output style: frontmatter + canonical body.
{
    printf -- '---\nname: %s\ndescription: Writing style directive (generated; do not edit — edit the canonical file)\n---\n\n' "$STYLE_NAME"
    cat "$CANONICAL_SRC"
} > "${CLAUDE_DIR}/output-styles/${SLUG}.md"

# Digest hook (the only deployed hook file; the review hook is settings config).
install -m 0755 "${STAGING}/digest.sh" "${CLAUDE_DIR}/hooks/style-digest.sh"

# Settings: write the pre-computed merge (backup first).
if [[ -f "$SETTINGS" ]]; then
    cp "$SETTINGS" "${SETTINGS}.bak.$(date +%Y%m%d%H%M%S)"
fi
printf '%s\n' "$MERGED" > "$SETTINGS"

echo "Installed (user tier) for style: ${STYLE_NAME} (JSON engine: ${ENGINE})"
echo "Fully quit and restart Claude Code (a /clear is not enough), then verify:"
echo "  1. Ask Claude whether the writing-style directive and the"
echo "     '${STYLE_NAME}' output style are active."
echo "  2. Confirm the digest line arrives with each prompt."
echo "  3. The review hook was sandbox-tested before install (style-author"
echo "     Phase 6); in live use it revises replies that break the rules."
