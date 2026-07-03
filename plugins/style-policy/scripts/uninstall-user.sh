#!/bin/bash
# SPDX-FileCopyrightText: 2026 Gary Frattarola
# SPDX-License-Identifier: MIT OR Apache-2.0
#
# User-tier uninstaller — NO sudo. Removes the deployed style policy from
# ~/.claude, leaving the canonical directive in the user's repo untouched.
#
# Usage: uninstall-user.sh [style-name]
set -euo pipefail

STYLE_NAME="${1:-Writing Style}"
SLUG=$(printf '%s' "$STYLE_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//')
CLAUDE_DIR="${HOME}/.claude"
HOOKS_DIR="${CLAUDE_DIR}/hooks"
STAMP=$(date +%Y%m%d%H%M%S)

# Drop the import line from ~/.claude/CLAUDE.md (back it up first).
CM="${CLAUDE_DIR}/CLAUDE.md"
IMPORT_LINE="@~/.claude/writing-style.md"
if [[ -f "$CM" ]]; then
    cp "$CM" "${CM}.bak.${STAMP}"
    grep -vxF "$IMPORT_LINE" "$CM" > "${CM}.tmp" || true
    mv "${CM}.tmp" "$CM"
fi

rm -f "${CLAUDE_DIR}/writing-style.md" \
      "${CLAUDE_DIR}/output-styles/${SLUG}.md" \
      "${HOOKS_DIR}/style-digest.sh" \
      "${HOOKS_DIR}/style-lint.py"

# Remove our keys from ~/.claude/settings.json, leaving any other settings.
S="${CLAUDE_DIR}/settings.json"
if [[ -f "$S" ]]; then
    cp "$S" "${S}.bak.${STAMP}"
    python3 - "$S" "$HOOKS_DIR" "$STYLE_NAME" <<'PY'
import json, sys
path, hooks_dir, style = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, encoding="utf-8") as f:
    d = json.load(f)
if d.get("outputStyle") == style:
    d.pop("outputStyle", None)
hooks = d.get("hooks", {})
for ev in ("UserPromptSubmit", "Stop"):
    kept = []
    for g in hooks.get(ev, []):
        hs = [h for h in g.get("hooks", []) if hooks_dir not in (h.get("command") or "")]
        if hs:
            kept.append({**g, "hooks": hs})
    if kept:
        hooks[ev] = kept
    else:
        hooks.pop(ev, None)
if hooks:
    d["hooks"] = hooks
else:
    d.pop("hooks", None)
with open(path, "w", encoding="utf-8") as f:
    json.dump(d, f, indent=2)
    f.write("\n")
PY
fi

echo "Removed user-tier policy for style: ${STYLE_NAME}"
echo "The canonical directive in your repo is untouched; reinstall anytime."
echo "Start a fresh session; the style is no longer applied."
