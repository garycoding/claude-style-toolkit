#!/bin/bash
# SPDX-FileCopyrightText: 2026 Gary Frattarola
# SPDX-License-Identifier: MIT OR Apache-2.0
#
# User-tier installer — NO sudo required. Deploys a staged style policy
# entirely under ~/.claude. Nothing is tamper-resistant at this tier;
# use build-managed-installer.sh for the root-owned variant.
#
# Usage: ./install-user.sh <staging-dir> [style-name]
#   <staging-dir> must contain: canonical.md, digest.sh, lint.py
#   [style-name]  display name for the output style (default: Writing Style)
#
# Actions (all idempotent):
#   ~/.claude/writing-style.md            <- canonical.md
#   ~/.claude/CLAUDE.md                   <- append @import line if absent
#   ~/.claude/output-styles/<slug>.md     <- frontmatter + canonical
#   ~/.claude/hooks/style-digest.sh,.py   <- hook scripts, chmod +x
#   ~/.claude/settings.json               <- outputStyle + hook entries
#                                            (merged; backup written first)
set -euo pipefail

STAGING="${1:?Usage: install-user.sh <staging-dir> [style-name]}"
STYLE_NAME="${2:-Writing Style}"
SLUG=$(printf '%s' "$STYLE_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//')

CLAUDE_DIR="${HOME}/.claude"
CANONICAL_SRC="${STAGING}/canonical.md"
for f in canonical.md digest.sh lint.py; do
    [[ -f "${STAGING}/${f}" ]] || { echo "Missing ${STAGING}/${f}" >&2; exit 1; }
done

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

# Hooks.
install -m 0755 "${STAGING}/digest.sh" "${CLAUDE_DIR}/hooks/style-digest.sh"
install -m 0755 "${STAGING}/lint.py"   "${CLAUDE_DIR}/hooks/style-lint.py"

# Settings merge (with backup).
SETTINGS="${CLAUDE_DIR}/settings.json"
if [[ -f "$SETTINGS" ]]; then
    cp "$SETTINGS" "${SETTINGS}.bak.$(date +%Y%m%d%H%M%S)"
fi
python3 - "$SETTINGS" "$STYLE_NAME" "${CLAUDE_DIR}/hooks" <<'PY'
import json, os, sys
path, style, hooks_dir = sys.argv[1], sys.argv[2], sys.argv[3]
data = {}
if os.path.exists(path):
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
data["outputStyle"] = style
hooks = data.setdefault("hooks", {})
def ensure(event, cmd):
    groups = hooks.setdefault(event, [])
    for g in groups:
        for h in g.get("hooks", []):
            if h.get("command") == cmd:
                return
    groups.append({"hooks": [{"type": "command", "command": cmd}]})
ensure("UserPromptSubmit", os.path.join(hooks_dir, "style-digest.sh"))
ensure("Stop", os.path.join(hooks_dir, "style-lint.py"))
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY

echo "Installed (user tier) for style: ${STYLE_NAME}"
echo "Start a fresh Claude Code session, then verify:"
echo "  1. Ask Claude whether the writing-style directive and the"
echo "     '${STYLE_NAME}' output style are active."
echo "  2. Confirm the digest line arrives with each prompt."
echo "  3. Request output violating a banned rule; the lint should block it."
