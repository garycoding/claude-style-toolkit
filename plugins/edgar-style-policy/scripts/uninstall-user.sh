#!/bin/bash
# SPDX-FileCopyrightText: 2026 Gary Frattarola
# SPDX-License-Identifier: MIT OR Apache-2.0
#
# User-tier uninstaller — NO sudo. Removes the deployed style policy from
# ~/.claude, leaving the canonical directive in the user's repo untouched.
# Settings surgery runs FIRST, so a failure leaves the install intact
# rather than dangling; files are removed only after it succeeds. Only the
# policy's own entries are touched: the digest hook is matched by its
# filename and the review hook by the "[writing-style-policy]" marker —
# any other hooks or settings the user has are preserved. JSON work runs
# on whichever engine the machine has (python3, osascript, or node).
#
# Usage: uninstall-user.sh [style-name]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=json-tool.sh
source "${SCRIPT_DIR}/json-tool.sh"

STYLE_NAME="${1:-Writing Style}"
SLUG=$(printf '%s' "$STYLE_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//')
[[ -n "$SLUG" ]] || SLUG="writing-style"
CLAUDE_DIR="${HOME}/.claude"
HOOKS_DIR="${CLAUDE_DIR}/hooks"
STAMP=$(date +%Y%m%d%H%M%S)

# Settings surgery first (with backup): remove our keys, preserve the rest.
S="${CLAUDE_DIR}/settings.json"
if [[ -f "$S" ]]; then
    ENGINE="$(detect_json_engine)"
    if [[ -z "$ENGINE" ]]; then
        echo "No JSON engine found (python3, osascript, or node) for the settings cleanup." >&2
        echo "On macOS: xcode-select --install. Nothing has been changed." >&2
        exit 1
    fi
    EXISTING="$(cat "$S")"
    CLEANED="$(STYLE="$STYLE_NAME" EXISTING="$EXISTING" json_transform strip)"
    cp "$S" "${S}.bak.${STAMP}"
    printf '%s\n' "$CLEANED" > "$S"
fi

# Drop the import line from ~/.claude/CLAUDE.md (back it up first), then
# collapse runs of blank lines left by install/uninstall cycles.
CM="${CLAUDE_DIR}/CLAUDE.md"
IMPORT_LINE="@~/.claude/writing-style.md"
if [[ -f "$CM" ]]; then
    cp "$CM" "${CM}.bak.${STAMP}"
    grep -vxF "$IMPORT_LINE" "$CM" > "${CM}.tmp" || true
    awk 'NF {blank=0; print; next} {blank++} blank<=1 {print}' "${CM}.tmp" > "${CM}.tmp2"
    mv "${CM}.tmp2" "$CM"
    rm -f "${CM}.tmp"
fi

rm -f "${CLAUDE_DIR}/writing-style.md" \
      "${CLAUDE_DIR}/output-styles/${SLUG}.md" \
      "${HOOKS_DIR}/style-digest.sh"

echo "Removed user-tier policy for style: ${STYLE_NAME}"
echo "The canonical directive in your repo is untouched; reinstall anytime."
echo "Fully quit and restart Claude Code; the style is no longer applied."
