#!/bin/bash
# SPDX-FileCopyrightText: 2026 Gary Frattarola
# SPDX-License-Identifier: MIT OR Apache-2.0
#
# User-tier uninstaller — NO sudo. Removes the deployed style policy from
# ~/.claude, leaving the style library untouched. Settings surgery runs
# FIRST, so a failure leaves the install intact rather than dangling; files
# are removed only after it succeeds. Only the policy's own entries are
# touched: hooks whose command names style-digest.sh or style-emoji-check.sh,
# the review hook by its "[writing-style-policy]" marker, and outputStyle
# when it names this style or another style the toolkit generated. Any other
# hooks or settings are preserved. JSON work runs on whichever engine the
# machine has (python3, osascript, or node).
#
# Usage: uninstall-user.sh [style-name]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=json-tool.sh
source "${SCRIPT_DIR}/json-tool.sh"

STYLE_NAME="${1:-Writing Style}"
CLAUDE_DIR="${HOME}/.claude"
HOOKS_DIR="${CLAUDE_DIR}/hooks"
STYLES_DIR="${CLAUDE_DIR}/output-styles"
STAMP="$(date +%Y%m%d%H%M%S).$$"

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
    if ! EXISTING="$EXISTING" json_transform validate >/dev/null 2>&1; then
        echo "~/.claude/settings.json is not valid JSON (or its root is not an object)." >&2
        echo "Fix or remove it, then rerun. Nothing has been changed." >&2
        exit 1
    fi
    CLEANED="$(STYLE="$STYLE_NAME" EXISTING="$EXISTING" \
        TOOLKIT_STYLES="$(toolkit_style_names "$STYLES_DIR")" json_transform strip)"
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

toolkit_style_files "$STYLES_DIR" | while IFS= read -r f; do rm -f "$f"; done
rm -f "${CLAUDE_DIR}/writing-style.md" \
      "${HOOKS_DIR}/style-digest.sh" \
      "${HOOKS_DIR}/style-emoji-check.sh" \
      "${HOOKS_DIR}/style-json-tool.sh"

echo "Removed user-tier policy for style: ${STYLE_NAME}"
echo "The style library is untouched; reinstall or switch back at any time."
echo "Fully quit and restart Claude Code; the style is no longer applied."
