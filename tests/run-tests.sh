#!/bin/bash
# SPDX-FileCopyrightText: 2026 Gary Frattarola
# SPDX-License-Identifier: MIT OR Apache-2.0
#
# Test harness for the toolkit's scripts. Runs everything in a scratch
# directory; touches neither ~/.claude nor the managed directory.
#   tests/run-tests.sh            all available engines (python3, osascript, node)
#   JSON_TOOL_ENGINE=node tests/run-tests.sh   one engine
# Exit status 0 when every check passes.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
S="${ROOT}/plugins/edgar-style-policy/scripts"
FX="${ROOT}/tests/fixtures"
# shellcheck source=../plugins/edgar-style-policy/scripts/json-tool.sh
source "${S}/json-tool.sh"
PASS=0; FAIL=0
ok()   { PASS=$((PASS + 1)); }
bad()  { FAIL=$((FAIL + 1)); echo "FAIL: $*"; }
check() { if eval "$2"; then ok; else bad "$1"; fi; }
jq_py() { python3 -c "import json,sys; d=json.load(sys.stdin); $1"; }

if [[ -n "${JSON_TOOL_ENGINE:-}" ]]; then
    ENGINES=("$JSON_TOOL_ENGINE")
else
    ENGINES=()
    python3 -c 'import json' >/dev/null 2>&1 && ENGINES+=(python3)
    [[ "$(uname -s)" == Darwin ]] && ENGINES+=(osascript)
    command -v node >/dev/null 2>&1 && ENGINES+=(node)
fi

for E in "${ENGINES[@]}"; do
    export JSON_TOOL_ENGINE="$E"

    # Migration: a legacy four-layer install, which includes a hook entry for
    # the retired emoji check, brought into line with a record of the digest
    # alone. Foreign hooks survive.
    EX="$(cat "${FX}/legacy-managed-settings.json")"
    F="$(STYLE="House Style" LAYERS="digest" json_transform fragment)"
    M="$(FRAGMENT="$F" EXISTING="$EX" STYLE="House Style" TOOLKIT_STYLES=$'House Style\nOther Style' json_transform merge)"
    check "$E merge drops outputStyle" "printf '%s' \"\$M\" | jq_py 'sys.exit(\"outputStyle\" in d)'"
    check "$E merge drops the review hook, keeps the foreign Stop hook" \
        "printf '%s' \"\$M\" | jq_py 'sys.exit([h.get(\"command\") for g in d[\"hooks\"][\"Stop\"] for h in g[\"hooks\"]] != [\"foreign-stop.sh\"])'"
    check "$E merge removes the retired emoji check and keeps the foreign PreToolUse hook" \
        "printf '%s' \"\$M\" | jq_py 'sys.exit([h.get(\"command\") for g in d[\"hooks\"][\"PreToolUse\"] for h in g[\"hooks\"]] != [\"foreign-lint.sh\"])'"
    FR="$(STYLE="House Style" LAYERS="digest commit-emoji-check" json_transform fragment)"
    check "$E a record naming the retired layer deploys no PreToolUse hook" \
        "printf '%s' \"\$FR\" | jq_py 'sys.exit(\"PreToolUse\" in d[\"hooks\"] or \"UserPromptSubmit\" not in d[\"hooks\"])'"
    check "$E merge keeps the foreign top-level setting" "printf '%s' \"\$M\" | jq_py 'sys.exit(d.get(\"permissions\") is None)'"
    M2="$(FRAGMENT="$F" EXISTING="$M" STYLE="House Style" json_transform merge)"
    check "$E merge is idempotent" "[[ \"\$M\" == \"\$M2\" ]]"
    ST="$(EXISTING="$M" STYLE="House Style" json_transform strip)"
    check "$E strip leaves only foreign entries (the retired emoji check is removed too)" \
        "printf '%s' \"\$ST\" | jq_py 'h=d[\"hooks\"]; cmds=sorted(x.get(\"command\",\"\") for v in h.values() for g in v for x in g[\"hooks\"]); sys.exit(sorted(h) != [\"PreToolUse\", \"Stop\"] or cmds != [\"foreign-lint.sh\", \"foreign-stop.sh\"])'"
    check "$E merge rejects a non-array event" \
        "! FRAGMENT=\"\$F\" EXISTING='{\"hooks\":{\"UserPromptSubmit\":\"weird\"}}' STYLE=x json_transform merge >/dev/null 2>&1"
done
unset JSON_TOOL_ENGINE

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

# The layer record: a folder without one deploys the directive and the digest
# only, never the output style or the review hook; a record is read as written.
mkdir -p "$T/rec"
check "a style without a layer record deploys the digest only" "[[ \"\$(read_layers \"$T/rec\")\" == digest ]]"
printf 'digest=on\ncommit-emoji-check=on\n' > "$T/rec/layers"
check "a layer record is read as written" "[[ \"\$(read_layers \"$T/rec\")\" == 'digest commit-emoji-check ' ]]"

# User tier: a style with no record, an older style with an explicit record,
# migration to the digest alone, uninstall back to the start.
mkdir -p "$T/home/.claude" "$T/lib"
cp -R "${FX}/style" "$T/lib/house-style"
cp "${FX}/user-settings.json" "$T/home/.claude/settings.json"
BEFORE="$(python3 -c 'import json,sys;print(json.dumps(json.load(open(sys.argv[1])),sort_keys=True))' "$T/home/.claude/settings.json")"
HOME="$T/home" "${S}/install-user.sh" "$T/lib/house-style" "House Style" >/dev/null
check "user install without a record deploys the digest hook" "[[ -x \"$T/home/.claude/hooks/style-digest.sh\" ]]"
check "user install without a record creates no output style and no review hook" \
    "[[ ! -e \"$T/home/.claude/output-styles\" ]] && ! command -p grep -q writing-style-policy \"$T/home/.claude/settings.json\""
printf 'digest=on\noutput-style=on\nstop-review=on\n' > "$T/lib/house-style/layers"
HOME="$T/home" "${S}/install-user.sh" "$T/lib/house-style" "House Style" >/dev/null
check "user install with an explicit older record selects the output style" "[[ -f \"$T/home/.claude/output-styles/house-style.md\" ]]"
printf '#!/bin/bash\n' > "$T/home/.claude/hooks/style-emoji-check.sh"; printf '' > "$T/home/.claude/hooks/style-json-tool.sh"
printf 'digest=on\n' > "$T/lib/house-style/layers"
HOME="$T/home" "${S}/install-user.sh" "$T/lib/house-style" "House Style" >/dev/null
check "user migration removes the output-style file" "[[ ! -e \"$T/home/.claude/output-styles/house-style.md\" ]]"
check "user migration removes the retired emoji check and its engine library" \
    "[[ ! -e \"$T/home/.claude/hooks/style-emoji-check.sh\" && ! -e \"$T/home/.claude/hooks/style-json-tool.sh\" ]]"
check "user migration installs no PreToolUse hook" "! command -p grep -q style-emoji-check \"$T/home/.claude/settings.json\""
HOME="$T/home" "${S}/uninstall-user.sh" "House Style" >/dev/null
AFTER="$(python3 -c 'import json,sys;print(json.dumps(json.load(open(sys.argv[1])),sort_keys=True))' "$T/home/.claude/settings.json")"
check "user uninstall restores the original settings" "[[ \"\$BEFORE\" == \"\$AFTER\" ]]"

# Managed tier, with the managed path and the root-only lines overridden.
ovr() { sed -e "s#MANAGED_DIR=\"/Library/Application Support/ClaudeCode\"#MANAGED_DIR=\"$2\"#" \
            -e "s#MANAGED_DIR=\"/etc/claude-code\"#MANAGED_DIR=\"$2\"#" \
            -e 's/^if \[\[ \$EUID -ne 0 \]\].*$/:/' -e 's/^TARGET_USER=.*$/:/' -e 's/^chown -R .*$/:/' "$1"; }
MD="$T/Application Support/ClaudeCode"; mkdir -p "$MD/hooks" "$MD/.claude/output-styles"
printf '#!/bin/bash\n' > "$MD/hooks/style-emoji-check.sh"
printf 'Organisation policy.\n' > "$MD/CLAUDE.md"
cp "${FX}/org-managed-settings.json" "$MD/managed-settings.json"
"${S}/build-managed-installer.sh" "$T/lib/house-style" "House Style" "$T/in.sh" >/dev/null
ovr "$T/in.sh" "$MD" > "$T/in-t.sh"; bash "$T/in-t.sh" >/dev/null
check "managed install keeps a foreign CLAUDE.md aside" "[[ -f \"$MD/CLAUDE.md.pre-edgar-style-policy\" ]]"
check "managed install writes the sidecar record" "command -p grep -q '^sha256=' \"$MD/.edgar-style-policy\""
check "managed install adds the digest beside the organisation's settings" "jq_py 'sys.exit(\"permissions\" not in d or \"UserPromptSubmit\" not in d[\"hooks\"] or \"PreToolUse\" in d[\"hooks\"])' < \"$MD/managed-settings.json\""
check "managed install removes a retired emoji check" "[[ ! -e \"$MD/hooks/style-emoji-check.sh\" ]]"
check "managed install removes the empty output-style directories" "[[ ! -d \"$MD/.claude\" ]]"
"${S}/build-managed-installer.sh" "$T/lib/house-style" "House Style" "$T/in2.sh" >/dev/null
ovr "$T/in2.sh" "$MD" > "$T/in2-t.sh"; bash "$T/in2-t.sh" >/dev/null
check "managed rerun recognises its own CLAUDE.md" "[[ \$(ls \"$MD\" | command -p grep -c 'CLAUDE.md.bak') -eq 0 ]]"
"${S}/build-managed-uninstaller.sh" "House Style" "$T/un.sh" "" "$T/lib" >/dev/null
ovr "$T/un.sh" "$MD" > "$T/un-t.sh"; bash "$T/un-t.sh" >/dev/null
check "managed uninstall restores the foreign CLAUDE.md" "[[ \"\$(cat \"$MD/CLAUDE.md\")\" == 'Organisation policy.' ]]"
check "managed uninstall keeps foreign settings" "jq_py 'sys.exit(d.get(\"permissions\") is None)' < \"$MD/managed-settings.json\""
check "managed uninstall removes the hook files" "[[ ! -e \"$MD/hooks/style-digest.sh\" ]]"

# Legacy managed installs, before the sidecar record: the toolkit's CLAUDE.md
# is recognised by a library canonical, or by the toolkit's markers.
MD2="$T/legacy one/ClaudeCode"; mkdir -p "$MD2/hooks"
cp "$T/lib/house-style/canonical.md" "$MD2/CLAUDE.md"
cp "${FX}/legacy-managed-settings.json" "$MD2/managed-settings.json"
"${S}/build-managed-installer.sh" "$T/lib/house-style" "House Style" "$T/in3.sh" >/dev/null
ovr "$T/in3.sh" "$MD2" > "$T/in3-t.sh"; bash "$T/in3-t.sh" >/dev/null
check "legacy install matching a library canonical is not set aside" "[[ ! -e \"$MD2/CLAUDE.md.pre-edgar-style-policy\" ]]"
check "legacy managed migration drops outputStyle and the review hook" \
    "jq_py 'sys.exit(\"outputStyle\" in d or any(x.get(\"type\")==\"prompt\" for g in d[\"hooks\"].get(\"Stop\",[]) for x in g[\"hooks\"]))' < \"$MD2/managed-settings.json\""
MD3="$T/legacy two/ClaudeCode"; mkdir -p "$MD3/hooks"
printf 'An edited directive no longer in the library.\n' > "$MD3/CLAUDE.md"
cp "${FX}/legacy-managed-settings.json" "$MD3/managed-settings.json"
"${S}/build-managed-installer.sh" "$T/lib/house-style" "House Style" "$T/in4.sh" >/dev/null
ovr "$T/in4.sh" "$MD3" > "$T/in4-t.sh"; bash "$T/in4-t.sh" >/dev/null
check "legacy install recognised by its settings markers is not set aside" "[[ ! -e \"$MD3/CLAUDE.md.pre-edgar-style-policy\" ]]"

echo "passed: ${PASS}, failed: ${FAIL}"
[[ $FAIL -eq 0 ]]
