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

    # Migration: a legacy four-layer install brought into line with a record
    # of digest and commit-emoji-check. Foreign hooks survive.
    EX="$(cat "${FX}/legacy-managed-settings.json")"
    F="$(STYLE="House Style" LAYERS="digest commit-emoji-check" json_transform fragment)"
    M="$(FRAGMENT="$F" EXISTING="$EX" STYLE="House Style" TOOLKIT_STYLES=$'House Style\nOther Style' json_transform merge)"
    check "$E merge drops outputStyle" "printf '%s' \"\$M\" | jq_py 'sys.exit(\"outputStyle\" in d)'"
    check "$E merge drops the review hook, keeps the foreign Stop hook" \
        "printf '%s' \"\$M\" | jq_py 'sys.exit([h.get(\"command\") for g in d[\"hooks\"][\"Stop\"] for h in g[\"hooks\"]] != [\"foreign-stop.sh\"])'"
    check "$E merge adds the emoji check beside the foreign PreToolUse hook" \
        "printf '%s' \"\$M\" | jq_py 'sys.exit(len(d[\"hooks\"][\"PreToolUse\"]) != 2)'"
    check "$E merge keeps the foreign top-level setting" "printf '%s' \"\$M\" | jq_py 'sys.exit(d.get(\"permissions\") is None)'"
    M2="$(FRAGMENT="$F" EXISTING="$M" STYLE="House Style" json_transform merge)"
    check "$E merge is idempotent" "[[ \"\$M\" == \"\$M2\" ]]"
    ST="$(EXISTING="$M" STYLE="House Style" json_transform strip)"
    check "$E strip leaves only foreign entries" \
        "printf '%s' \"\$ST\" | jq_py 'h=d[\"hooks\"]; cmds=sorted(x.get(\"command\",\"\") for v in h.values() for g in v for x in g[\"hooks\"]); sys.exit(sorted(h) != [\"PreToolUse\", \"Stop\"] or cmds != [\"foreign-lint.sh\", \"foreign-stop.sh\"])'"
    check "$E merge rejects a non-array event" \
        "! FRAGMENT=\"\$F\" EXISTING='{\"hooks\":{\"PreToolUse\":\"weird\"}}' STYLE=x json_transform merge >/dev/null 2>&1"

    # Emoji scan cases: name, expected verdict, command.
    while IFS=$'\t' read -r name expect cmd; do
        [[ -z "$name" || "$name" == \#* ]] && continue
        cmd="$(printf '%b' "$cmd")"
        IN="$(CMD="$cmd" CWD="$FX" python3 -c 'import json,os;print(json.dumps({"tool_input":{"command":os.environ["CMD"]},"cwd":os.environ["CWD"]}))')"
        R="$(INPUT="$IN" json_transform emoji-scan | head -1)"
        check "$E emoji-scan: $name" "[[ \"\$R\" == ${expect}* ]]"
    done < "${FX}/emoji-cases.tsv"
done
unset JSON_TOOL_ENGINE

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

# The hook end to end: refused once, the unchanged rerun passes.
cp "${S}/style-emoji-check.sh" "$T/"; cp "${S}/json-tool.sh" "$T/style-json-tool.sh"
IN="$(python3 -c 'import json;print(json.dumps({"tool_input":{"command":"git commit -m \"feat \U0001F916\""},"cwd":"/tmp"}))')"
printf '%s' "$IN" | XDG_STATE_HOME="$T/state" "$T/style-emoji-check.sh" 2>/dev/null; A=$?
printf '%s' "$IN" | XDG_STATE_HOME="$T/state" "$T/style-emoji-check.sh" 2>/dev/null; B=$?
check "hook refuses once (exit 2), then passes (exit 0)" "[[ $A -eq 2 && $B -eq 0 ]]"
printf '%s' "$IN" | XDG_STATE_HOME="$T/state" "$T/style-emoji-check.sh" 2>/dev/null; C=$?
check "hook keeps passing a text it has refused once" "[[ $C -eq 0 ]]"
printf '{"tool_input":{"command":"git commit {not json' | XDG_STATE_HOME="$T/state" "$T/style-emoji-check.sh" 2>/dev/null
check "hook fails open on unreadable input" "[[ $? -eq 0 ]]"
IN3="$(python3 -c 'import json;print(json.dumps({"tool_input":{"command":"ls -la"},"cwd":"/Users/x/dev/github/y"}))')"
printf '%s' "$IN3" | XDG_STATE_HOME="$T/state" JSON_TOOL_ENGINE=none "$T/style-emoji-check.sh" 2>/dev/null
check "hook passes a non-git command without an engine" "[[ $? -eq 0 ]]"

# User tier: legacy install, migration to a record, uninstall back to the start.
mkdir -p "$T/home/.claude" "$T/lib"
cp -R "${FX}/style" "$T/lib/house-style"
cp "${FX}/user-settings.json" "$T/home/.claude/settings.json"
BEFORE="$(python3 -c 'import json,sys;print(json.dumps(json.load(open(sys.argv[1])),sort_keys=True))' "$T/home/.claude/settings.json")"
HOME="$T/home" "${S}/install-user.sh" "$T/lib/house-style" "House Style" >/dev/null
check "user legacy install selects the output style" "[[ -f \"$T/home/.claude/output-styles/house-style.md\" ]]"
printf 'digest=on\ncommit-emoji-check=on\n' > "$T/lib/house-style/layers"
HOME="$T/home" "${S}/install-user.sh" "$T/lib/house-style" "House Style" >/dev/null
check "user migration removes the output-style file" "[[ ! -e \"$T/home/.claude/output-styles/house-style.md\" ]]"
check "user migration installs the emoji check" "[[ -x \"$T/home/.claude/hooks/style-emoji-check.sh\" && -f \"$T/home/.claude/hooks/style-json-tool.sh\" ]]"
HOME="$T/home" "${S}/uninstall-user.sh" "House Style" >/dev/null
AFTER="$(python3 -c 'import json,sys;print(json.dumps(json.load(open(sys.argv[1])),sort_keys=True))' "$T/home/.claude/settings.json")"
check "user uninstall restores the original settings" "[[ \"\$BEFORE\" == \"\$AFTER\" ]]"

# Managed tier, with the managed path and the root-only lines overridden.
ovr() { sed -e "s#MANAGED_DIR=\"/Library/Application Support/ClaudeCode\"#MANAGED_DIR=\"$2\"#" \
            -e "s#MANAGED_DIR=\"/etc/claude-code\"#MANAGED_DIR=\"$2\"#" \
            -e 's/^if \[\[ \$EUID -ne 0 \]\].*$/:/' -e 's/^TARGET_USER=.*$/:/' -e 's/^chown -R .*$/:/' "$1"; }
MD="$T/Application Support/ClaudeCode"; mkdir -p "$MD"
printf 'Organisation policy.\n' > "$MD/CLAUDE.md"
cp "${FX}/org-managed-settings.json" "$MD/managed-settings.json"
"${S}/build-managed-installer.sh" "$T/lib/house-style" "House Style" "$T/in.sh" >/dev/null
ovr "$T/in.sh" "$MD" > "$T/in-t.sh"; bash "$T/in-t.sh" >/dev/null
check "managed install keeps a foreign CLAUDE.md aside" "[[ -f \"$MD/CLAUDE.md.pre-edgar-style-policy\" ]]"
check "managed install writes the sidecar record" "command -p grep -q '^sha256=' \"$MD/.edgar-style-policy\""
check "managed install adds the emoji check beside the organisation's settings" "jq_py 'sys.exit(\"permissions\" not in d or \"PreToolUse\" not in d[\"hooks\"])' < \"$MD/managed-settings.json\""
"${S}/build-managed-installer.sh" "$T/lib/house-style" "House Style" "$T/in2.sh" >/dev/null
ovr "$T/in2.sh" "$MD" > "$T/in2-t.sh"; bash "$T/in2-t.sh" >/dev/null
check "managed rerun recognises its own CLAUDE.md" "[[ \$(ls \"$MD\" | command -p grep -c 'CLAUDE.md.bak') -eq 0 ]]"
"${S}/build-managed-uninstaller.sh" "House Style" "$T/un.sh" "" "$T/lib" >/dev/null
ovr "$T/un.sh" "$MD" > "$T/un-t.sh"; bash "$T/un-t.sh" >/dev/null
check "managed uninstall restores the foreign CLAUDE.md" "[[ \"\$(cat \"$MD/CLAUDE.md\")\" == 'Organisation policy.' ]]"
check "managed uninstall keeps foreign settings" "jq_py 'sys.exit(d.get(\"permissions\") is None)' < \"$MD/managed-settings.json\""
check "managed uninstall removes the hook files" "[[ ! -e \"$MD/hooks/style-emoji-check.sh\" && ! -e \"$MD/hooks/style-digest.sh\" ]]"

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
