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
# Actions (all idempotent):
#   ~/.claude/writing-style.md            <- canonical.md
#   ~/.claude/CLAUDE.md                   <- append @import line if absent
#   ~/.claude/output-styles/<slug>.md     <- frontmatter + canonical
#   ~/.claude/hooks/style-digest.sh       <- digest hook, chmod +x
#   ~/.claude/settings.json               <- outputStyle + digest command hook
#                                            + judgment-review prompt hook
#                                            (merged; backup written first)
set -euo pipefail

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

# Preflight BEFORE any mutation: python3 must execute (a stock Mac without
# Command Line Tools has a stub that resolves but fails), and any existing
# settings.json must parse, or we abort cleanly rather than half-install.
if ! python3 -c 'import json' >/dev/null 2>&1; then
    echo "python3 is required for the settings merge. On macOS run:" >&2
    echo "    xcode-select --install" >&2
    echo "then rerun this installer. Nothing has been changed." >&2
    exit 1
fi
if [[ -f "$SETTINGS" ]] && ! python3 - "$SETTINGS" >/dev/null 2>&1 <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    d = json.load(f)
assert isinstance(d, dict)
assert isinstance(d.get("hooks", {}), dict)
PY
then
    echo "~/.claude/settings.json is not valid JSON (or has a malformed hooks key)." >&2
    echo "Fix or remove it, then rerun. Nothing has been changed." >&2
    exit 1
fi

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

# Settings merge (with backup): outputStyle, digest command hook, and the
# judgment-review prompt hook. Existing review hooks bearing our marker are
# replaced so prompt updates apply on re-install.
if [[ -f "$SETTINGS" ]]; then
    cp "$SETTINGS" "${SETTINGS}.bak.$(date +%Y%m%d%H%M%S)"
fi
python3 - "$SETTINGS" "$STYLE_NAME" "${CLAUDE_DIR}/hooks" "${STAGING}/review-prompt.txt" <<'PY'
import json, os, sys
path, style, hooks_dir, prompt_path = sys.argv[1:5]
MARKER = "[writing-style-policy]"
with open(prompt_path, encoding="utf-8") as f:
    prompt = f.read().strip()
if not prompt.startswith(MARKER):
    prompt = MARKER + " " + prompt
data = {}
if os.path.exists(path):
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
data["outputStyle"] = style
hooks = data.setdefault("hooks", {})

digest_cmd = os.path.join(hooks_dir, "style-digest.sh")
groups = hooks.setdefault("UserPromptSubmit", [])
if not any(h.get("command") == digest_cmd
           for g in groups for h in g.get("hooks", [])):
    groups.append({"hooks": [{"type": "command", "command": digest_cmd}]})

stop = hooks.setdefault("Stop", [])
kept = []
for g in stop:
    hs = [h for h in g.get("hooks", [])
          if not (h.get("type") == "prompt"
                  and str(h.get("prompt", "")).startswith(MARKER))]
    if hs:
        kept.append({**g, "hooks": hs})
kept.append({"hooks": [{"type": "prompt", "prompt": prompt}]})
hooks["Stop"] = kept

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY

echo "Installed (user tier) for style: ${STYLE_NAME}"
echo "Fully quit and restart Claude Code (a /clear is not enough), then verify:"
echo "  1. Ask Claude whether the writing-style directive and the"
echo "     '${STYLE_NAME}' output style are active."
echo "  2. Confirm the digest line arrives with each prompt."
echo "  3. The review hook was sandbox-tested before install (style-author"
echo "     Phase 6); in live use it revises replies that break the rules."
