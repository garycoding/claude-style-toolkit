#!/bin/bash
# SPDX-FileCopyrightText: 2026 Gary Frattarola
# SPDX-License-Identifier: MIT OR Apache-2.0
#
# User-tier installer — NO sudo required. Deploys a staged style policy
# entirely under ~/.claude. Nothing is tamper-resistant at this tier;
# use build-managed-installer.sh for the root-owned variant.
#
# Usage: ./install-user.sh <staging-dir> [style-name]
#   <staging-dir> is the style's library folder. It must contain
#                 canonical.md, plus digest.sh when the digest layer is on
#                 and review-prompt.txt when the stop-review layer is on.
#                 Its "layers" file (lines "<layer>=on") says which layers
#                 are deployed; a folder without one keeps the original four.
#   [style-name]  display name of the style (default: Writing Style)
#
# JSON work runs on whichever engine the machine has — python3, osascript
# (macOS), or node — via json-tool.sh. Identical behavior on macOS and Linux.
#
# The run brings ~/.claude exactly into line with the layer record (all
# idempotent; toolkit entries the record lacks are removed):
#   ~/.claude/writing-style.md            <- canonical.md (always)
#   ~/.claude/CLAUDE.md                   <- @import line appended if absent
#   ~/.claude/output-styles/<slug>.md     <- output-style layer, else every
#                                            toolkit-generated style file removed
#   ~/.claude/hooks/style-digest.sh       <- digest layer
#   ~/.claude/hooks/style-emoji-check.sh  <- commit-emoji-check layer, with
#   ~/.claude/hooks/style-json-tool.sh       its JSON engine library
#   ~/.claude/settings.json               <- outputStyle and the hooks for the
#                                            layers that are on (merged; backup first)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=json-tool.sh
source "${SCRIPT_DIR}/json-tool.sh"

STAGING="${1:?Usage: install-user.sh <staging-dir> [style-name]}"
STYLE_NAME="${2:-Writing Style}"
case "$STYLE_NAME" in
    *$'\n'*)   echo "Style name must not contain newlines." >&2; exit 1 ;;
    \"*|\'*)   echo "Style name must not start with a quote." >&2; exit 1 ;;
esac
[[ -n "${STYLE_NAME// /}" ]] || { echo "Style name must not be empty." >&2; exit 1; }
SLUG=$(printf '%s' "$STYLE_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//')
[[ -n "$SLUG" ]] || SLUG="writing-style"

CLAUDE_DIR="${HOME}/.claude"
HOOKS_DIR="${CLAUDE_DIR}/hooks"
STYLES_DIR="${CLAUDE_DIR}/output-styles"
CANONICAL_SRC="${STAGING}/canonical.md"
SETTINGS="${CLAUDE_DIR}/settings.json"
LAYERS="$(read_layers "$STAGING")"

REQUIRED=(canonical.md)
has_layer "$LAYERS" digest && REQUIRED+=(digest.sh)
has_layer "$LAYERS" stop-review && REQUIRED+=(review-prompt.txt)
for f in "${REQUIRED[@]}"; do
    [[ -f "${STAGING}/${f}" ]] || { echo "Missing ${STAGING}/${f}" >&2; exit 1; }
    grep -qF "__CS_HOOKS_DIR__" "${STAGING}/${f}" && {
        echo "Staged ${f} contains the reserved placeholder __CS_HOOKS_DIR__; remove it." >&2; exit 1; } || true
done
if has_layer "$LAYERS" commit-emoji-check; then
    for f in style-emoji-check.sh json-tool.sh; do
        [[ -f "${SCRIPT_DIR}/${f}" ]] || { echo "Missing toolkit file ${SCRIPT_DIR}/${f}" >&2; exit 1; }
    done
fi

# Preflight BEFORE any mutation: an engine must exist, and any existing
# settings.json must parse, or we abort cleanly rather than half-install.
ENGINE="$(detect_json_engine)"
if [[ -z "$ENGINE" ]]; then
    echo "No JSON engine found (python3, osascript, or node)." >&2
    echo "On macOS run: xcode-select --install   (or use the skill's model-merge fallback)" >&2
    echo "On Linux run: sudo apt install python3. Nothing has been changed." >&2
    exit 1
fi
EXISTING=""
if [[ -f "$SETTINGS" ]]; then
    EXISTING="$(cat "$SETTINGS")"
    if [[ -z "${EXISTING//[$' \t\n']/}" ]]; then
        EXISTING=""   # empty file: treat as absent, matching the managed tier
    elif ! EXISTING="$EXISTING" json_transform validate >/dev/null 2>&1; then
        echo "~/.claude/settings.json is not valid JSON (or its root is not an object)." >&2
        echo "Fix or remove it, then rerun. Nothing has been changed." >&2
        exit 1
    fi
fi

# Build the merged settings up front (pure transforms; nothing written yet).
PROMPT=""
has_layer "$LAYERS" stop-review && PROMPT="$(cat "${STAGING}/review-prompt.txt")"
TOOLKIT_STYLES="$(toolkit_style_names "$STYLES_DIR")"
FRAGMENT="$(STYLE="$STYLE_NAME" LAYERS="$LAYERS" PROMPT="$PROMPT" json_transform fragment)"
FRAGMENT="${FRAGMENT//__CS_HOOKS_DIR__/${HOOKS_DIR}}"
MERGED="$(FRAGMENT="$FRAGMENT" EXISTING="$EXISTING" STYLE="$STYLE_NAME" \
    TOOLKIT_STYLES="$TOOLKIT_STYLES" json_transform merge)"

mkdir -p "$HOOKS_DIR" "$STYLES_DIR"

# Canonical copy + import from the global CLAUDE.md (append, never overwrite).
cp "$CANONICAL_SRC" "${CLAUDE_DIR}/writing-style.md"
IMPORT_LINE="@~/.claude/writing-style.md"
touch "${CLAUDE_DIR}/CLAUDE.md"
if ! grep -qxF "$IMPORT_LINE" "${CLAUDE_DIR}/CLAUDE.md"; then
    printf '\n%s\n' "$IMPORT_LINE" >> "${CLAUDE_DIR}/CLAUDE.md"
    echo "Added import line to ~/.claude/CLAUDE.md"
fi

# Output style: written when the layer is on; otherwise every style file the
# toolkit generated is removed, so none stays selectable.
toolkit_style_files "$STYLES_DIR" | while IFS= read -r f; do rm -f "$f"; done
if has_layer "$LAYERS" output-style; then
    {
        printf -- '---\nname: %s\ndescription: Writing style directive (generated; do not edit — edit the canonical file)\n' "$STYLE_NAME"
        has_layer "$LAYERS" output-style-coding && printf 'keep-coding-instructions: true\n'
        printf -- '---\n\n'
        cat "$CANONICAL_SRC"
    } > "${STYLES_DIR}/${SLUG}.md"
fi

# Hook files for the layers that are on; the others removed.
if has_layer "$LAYERS" digest; then
    install -m 0755 "${STAGING}/digest.sh" "${HOOKS_DIR}/style-digest.sh"
else
    rm -f "${HOOKS_DIR}/style-digest.sh"
fi
if has_layer "$LAYERS" commit-emoji-check; then
    install -m 0755 "${SCRIPT_DIR}/style-emoji-check.sh" "${HOOKS_DIR}/style-emoji-check.sh"
    install -m 0644 "${SCRIPT_DIR}/json-tool.sh" "${HOOKS_DIR}/style-json-tool.sh"
else
    rm -f "${HOOKS_DIR}/style-emoji-check.sh" "${HOOKS_DIR}/style-json-tool.sh"
fi

# Settings: write the pre-computed merge (backup first).
if [[ -f "$SETTINGS" ]]; then
    cp "$SETTINGS" "${SETTINGS}.bak.$(date +%Y%m%d%H%M%S).$$"
fi
printf '%s\n' "$MERGED" > "$SETTINGS"

echo "Installed (user tier) for style: ${STYLE_NAME} (JSON engine: ${ENGINE})"
echo "Layers on: CLAUDE.md ${LAYERS}"
echo "Fully quit and restart Claude Code (a /clear is not enough), then verify:"
echo "  1. Ask Claude whether the writing-style directive is in its context."
has_layer "$LAYERS" digest && echo "  2. Confirm the digest line arrives with each prompt."
has_layer "$LAYERS" commit-emoji-check && \
    echo "  3. A commit whose message carries an emoji is refused once, with the judgement asked for."
exit 0
