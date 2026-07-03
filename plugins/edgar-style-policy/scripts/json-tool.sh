# SPDX-FileCopyrightText: 2026 Gary Frattarola
# SPDX-License-Identifier: MIT OR Apache-2.0
#
# Shared JSON engine dispatch — sourced by the user-tier scripts and inlined
# into the emitted managed installer/uninstaller at build time. Works the
# same on macOS and Linux: python3 if it executes, else a JavaScript engine
# (osascript on macOS, node elsewhere). All operations are pure transforms:
# inputs via environment variables, result on stdout, nonzero exit on any
# parse failure. No engine touches the filesystem.
#
#   detect_json_engine            -> prints python3 | osascript | node | ""
#   json_transform <op>           ops: fragment | merge | strip | validate
#     fragment: env STYLE, PROMPT           -> settings fragment JSON
#     merge:    env FRAGMENT, EXISTING      -> merged settings JSON
#     strip:    env STYLE, EXISTING         -> cleaned settings JSON
#     validate: env EXISTING                -> exits 0 iff valid JSON
#
# JSON_TOOL_ENGINE overrides detection (used by tests).

detect_json_engine() {
    if [[ -n "${JSON_TOOL_ENGINE:-}" ]]; then printf '%s' "$JSON_TOOL_ENGINE"; return; fi
    if python3 -c 'import json' >/dev/null 2>&1; then printf 'python3'; return; fi
    if [[ "$(uname -s)" == "Darwin" ]] && command -v osascript >/dev/null 2>&1; then printf 'osascript'; return; fi
    if command -v node >/dev/null 2>&1; then printf 'node'; return; fi
    printf ''
}

_JSON_TOOL_PY='
import json, os, sys
MARKER = "[writing-style-policy]"
op = sys.argv[1]
def _pc(_):
    raise ValueError("non-finite numbers are not valid JSON")
def jloads(s):
    return json.loads(s, parse_constant=_pc)
def need_settings_object(v):
    if not isinstance(v, dict) or not isinstance(v.get("hooks", {}), dict):
        print("settings root (and any hooks key) must be a JSON object", file=sys.stderr)
        sys.exit(1)
    return v
def load_env(name, default=None):
    v = os.environ.get(name, "")
    if not v.strip():
        return default
    return jloads(v)
if op == "validate":
    need_settings_object(jloads(os.environ["EXISTING"])); sys.exit(0)
if op == "fragment":
    prompt = os.environ.get("PROMPT", "").strip()
    style = os.environ.get("STYLE", "")
    if not prompt or not style:
        print("fragment requires non-empty STYLE and PROMPT", file=sys.stderr)
        sys.exit(1)
    if not prompt.startswith(MARKER):
        prompt = MARKER + " " + prompt
    out = {"outputStyle": style, "hooks": {
        "UserPromptSubmit": [{"hooks": [{"type": "command",
            "command": "\"__CS_HOOKS_DIR__/style-digest.sh\""}]}],
        "Stop": [{"hooks": [{"type": "prompt", "prompt": prompt}]}]}}
elif op == "merge":
    frag = jloads(os.environ["FRAGMENT"])
    out = need_settings_object(load_env("EXISTING", {}))
    out["outputStyle"] = frag["outputStyle"]
    hooks = out.setdefault("hooks", {})
    dc = frag["hooks"]["UserPromptSubmit"][0]["hooks"][0]["command"]
    gs = hooks.setdefault("UserPromptSubmit", [])
    if not any(h.get("command") == dc for g in gs for h in g.get("hooks", [])):
        gs.append(frag["hooks"]["UserPromptSubmit"][0])
    kept = []
    for g in hooks.get("Stop", []):
        hs = [h for h in g.get("hooks", [])
              if not (h.get("type") == "prompt"
                      and str(h.get("prompt", "")).startswith(MARKER))]
        if hs:
            kept.append({**g, "hooks": hs})
    kept.append(frag["hooks"]["Stop"][0])
    hooks["Stop"] = kept
elif op == "strip":
    style = os.environ["STYLE"]
    out = need_settings_object(load_env("EXISTING", {}))
    if out.get("outputStyle") == style:
        out.pop("outputStyle", None)
    hooks = out.get("hooks", {})
    for ev in ("UserPromptSubmit", "Stop"):
        kept = []
        for g in hooks.get(ev, []):
            hs = [h for h in g.get("hooks", [])
                  if "style-digest.sh" not in (h.get("command") or "")
                  and not (h.get("type") == "prompt"
                           and str(h.get("prompt", "")).startswith(MARKER))]
            if hs:
                kept.append({**g, "hooks": hs})
        if kept:
            hooks[ev] = kept
        else:
            hooks.pop(ev, None)
    if hooks:
        out["hooks"] = hooks
    else:
        out.pop("hooks", None)
else:
    sys.exit(2)
print(json.dumps(out, indent=2, ensure_ascii=False, allow_nan=False))
'

# Engine-neutral JS core: transform(op, env) -> string or null (validate).
_JSON_TOOL_JS_CORE='
const MARKER = "[writing-style-policy]";
function transform(op, env) {
    const loadEnv = (name, dflt) => {
        const v = env(name) || "";
        return v.trim() ? JSON.parse(v) : dflt;
    };
    const needSettingsObject = (v) => {
        const bad = (x) => typeof x !== "object" || x === null || Array.isArray(x);
        if (bad(v) || (v.hooks !== undefined && bad(v.hooks)))
            throw new Error("settings root (and any hooks key) must be a JSON object");
        return v;
    };
    if (op === "validate") { needSettingsObject(JSON.parse(env("EXISTING"))); return null; }
    let out;
    if (op === "fragment") {
        let p = (env("PROMPT") || "").trim();
        const style = env("STYLE") || "";
        if (!p || !style) throw new Error("fragment requires non-empty STYLE and PROMPT");
        if (!p.startsWith(MARKER)) p = MARKER + " " + p;
        out = {outputStyle: style, hooks: {
            UserPromptSubmit: [{hooks: [{type: "command",
                command: "\"__CS_HOOKS_DIR__/style-digest.sh\""}]}],
            Stop: [{hooks: [{type: "prompt", prompt: p}]}]}};
    } else if (op === "merge") {
        const frag = JSON.parse(env("FRAGMENT"));
        out = needSettingsObject(loadEnv("EXISTING", {}));
        out.outputStyle = frag.outputStyle;
        const hooks = out.hooks = out.hooks || {};
        const dc = frag.hooks.UserPromptSubmit[0].hooks[0].command;
        const gs = hooks.UserPromptSubmit = hooks.UserPromptSubmit || [];
        if (!gs.some(g => (g.hooks || []).some(h => h.command === dc)))
            gs.push(frag.hooks.UserPromptSubmit[0]);
        const kept = [];
        for (const g of hooks.Stop || []) {
            const hs = (g.hooks || []).filter(h => !(h.type === "prompt"
                && String(h.prompt || "").startsWith(MARKER)));
            if (hs.length) kept.push(Object.assign({}, g, {hooks: hs}));
        }
        kept.push(frag.hooks.Stop[0]);
        hooks.Stop = kept;
    } else if (op === "strip") {
        const style = env("STYLE");
        out = needSettingsObject(loadEnv("EXISTING", {}));
        if (out.outputStyle === style) delete out.outputStyle;
        const hooks = out.hooks || {};
        for (const ev of ["UserPromptSubmit", "Stop"]) {
            const kept = [];
            for (const g of hooks[ev] || []) {
                const hs = (g.hooks || []).filter(h =>
                    (h.command || "").indexOf("style-digest.sh") === -1
                    && !(h.type === "prompt"
                         && String(h.prompt || "").startsWith(MARKER)));
                if (hs.length) kept.push(Object.assign({}, g, {hooks: hs}));
            }
            if (kept.length) hooks[ev] = kept; else delete hooks[ev];
        }
        if (Object.keys(hooks).length) out.hooks = hooks; else delete out.hooks;
    } else {
        throw new Error("unknown op");
    }
    return JSON.stringify(out, null, 2);
}
'

json_transform() {
    local op="$1" engine
    engine="$(detect_json_engine)"
    case "$engine" in
        python3)
            python3 -c "$_JSON_TOOL_PY" "$op"
            ;;
        osascript)
            osascript -l JavaScript -e "${_JSON_TOOL_JS_CORE}
function run(argv) {
    ObjC.import(\"Foundation\");
    const envDict = \$.NSProcessInfo.processInfo.environment;
    const env = (n) => { const v = envDict.objectForKey(n); return v.isNil() ? \"\" : ObjC.unwrap(v); };
    const r = transform(argv[0], env);
    return r === null ? \"\" : r;
}" "$op"
            ;;
        node)
            node -e "${_JSON_TOOL_JS_CORE}
const r = transform(process.argv[1], (n) => process.env[n] || \"\");
if (r !== null) console.log(r);" "$op"
            ;;
        *)
            echo "No JSON engine available (need python3, osascript, or node)." >&2
            return 2
            ;;
    esac
}
