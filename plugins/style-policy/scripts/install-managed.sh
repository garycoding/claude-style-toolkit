#!/bin/bash
# SPDX-FileCopyrightText: 2026 Gary Frattarola
# SPDX-License-Identifier: MIT OR Apache-2.0
#
# Managed-tier installer — requires sudo. Deploys a staged style policy
# root-owned so no user-space tool can modify it. The harness cannot
# enter passwords: the guiding skill stages everything, then the USER
# runs this in a terminal:  sudo ./install-managed.sh <staging-dir> [name]
#
# <staging-dir> must contain: canonical.md, digest.sh, lint.py
#
# WARNING: writes <managed dir>/managed-settings.json. If one already
# exists it is backed up alongside, then replaced.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Run with sudo." >&2
    exit 1
fi

STAGING="${1:?Usage: sudo install-managed.sh <staging-dir> [style-name]}"
STYLE_NAME="${2:-Writing Style}"
SLUG=$(printf '%s' "$STYLE_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//')

case "$(uname -s)" in
    Darwin) MANAGED_DIR="/Library/Application Support/ClaudeCode"; GROUP="wheel" ;;
    Linux)  MANAGED_DIR="/etc/claude-code"; GROUP="root" ;;
    *) echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac

for f in canonical.md digest.sh lint.py; do
    [[ -f "${STAGING}/${f}" ]] || { echo "Missing ${STAGING}/${f}" >&2; exit 1; }
done

HOOKS_DIR="${MANAGED_DIR}/hooks"
STYLE_DIR="${MANAGED_DIR}/.claude/output-styles"

mkdir -p "$HOOKS_DIR" "$STYLE_DIR"
chown "root:${GROUP}" "$MANAGED_DIR" "$HOOKS_DIR" "${MANAGED_DIR}/.claude" "$STYLE_DIR"

install -m 0644 -o root -g "$GROUP" "${STAGING}/canonical.md" "${MANAGED_DIR}/CLAUDE.md"
install -m 0755 -o root -g "$GROUP" "${STAGING}/digest.sh" "${HOOKS_DIR}/style-digest.sh"
install -m 0755 -o root -g "$GROUP" "${STAGING}/lint.py"   "${HOOKS_DIR}/style-lint.py"

{
    printf -- '---\nname: %s\ndescription: Writing style directive (managed; do not edit — edit the canonical file)\n---\n\n' "$STYLE_NAME"
    cat "${STAGING}/canonical.md"
} > "${STYLE_DIR}/${SLUG}.md"
chown "root:${GROUP}" "${STYLE_DIR}/${SLUG}.md"
chmod 0644 "${STYLE_DIR}/${SLUG}.md"

MS="${MANAGED_DIR}/managed-settings.json"
if [[ -f "$MS" ]]; then
    cp "$MS" "${MS}.bak.$(date +%Y%m%d%H%M%S)"
    echo "Existing managed-settings.json backed up."
fi
cat > "$MS" <<JSON
{
  "outputStyle": "${STYLE_NAME}",
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [ { "type": "command", "command": "\"${HOOKS_DIR}/style-digest.sh\"" } ] }
    ],
    "Stop": [
      { "hooks": [ { "type": "command", "command": "\"${HOOKS_DIR}/style-lint.py\"" } ] }
    ]
  }
}
JSON
chown "root:${GROUP}" "$MS"
chmod 0644 "$MS"

echo "Installed (managed tier) to ${MANAGED_DIR} for style: ${STYLE_NAME}"
echo "Start a fresh Claude Code session, then verify:"
echo "  1. Ask Claude whether a managed CLAUDE.md and the '${STYLE_NAME}'"
echo "     output style are active."
echo "  2. Confirm the digest line arrives with each prompt."
echo "  3. Request output violating a banned rule; the lint should block it."
