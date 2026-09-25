# SPDX-FileCopyrightText: 2026 Gary Frattarola
# SPDX-License-Identifier: MIT OR Apache-2.0
#
# Shared JSON engine dispatch — sourced by the user-tier scripts, inlined
# into the emitted managed installer/uninstaller at build time, and deployed
# beside the commit emoji check as style-json-tool.sh. Works the same on
# macOS and Linux: python3 if it executes, else a JavaScript engine
# (osascript on macOS, node elsewhere). Inputs via environment variables,
# result on stdout, nonzero exit on any parse failure. The settings
# transforms touch no file; emoji-scan alone reads, never writes, the message
# files a git or gh command names.
#
#   detect_json_engine            -> prints python3 | osascript | node | ""
#   json_transform <op>           ops: fragment | merge | strip | validate | emoji-scan
#     fragment:   env STYLE, LAYERS, PROMPT      -> settings fragment JSON
#     merge:      env FRAGMENT, EXISTING, STYLE, TOOLKIT_STYLES
#                                                -> settings brought exactly into
#                                                   line with the fragment
#     strip:      env STYLE, EXISTING, TOOLKIT_STYLES -> cleaned settings JSON
#     validate:   env EXISTING                   -> exits 0 iff valid JSON
#     emoji-scan: env INPUT (PreToolUse hook input JSON)
#                                                -> "none", or "hit U+XXXX ..." then
#                                                   the scanned text (for fingerprinting)
#
# LAYERS is a space-separated list of the layers that are on:
#   digest, output-style, output-style-coding, stop-review, commit-emoji-check
# (the CLAUDE.md layer is file-only and always on). TOOLKIT_STYLES is a
# newline-separated list of style display names the toolkit deployed; an
# outputStyle naming one of them (or STYLE) is the toolkit's to remove.
# Our hooks are recognised by the reserved file names style-digest.sh and
# style-emoji-check.sh in their command, and the review hook by its
# "[writing-style-policy]" prompt marker.
#
# JSON_TOOL_ENGINE overrides detection (used by tests).

# Layers a bundle turns on, from its layer record ("<layer>=on" lines in
# <bundle>/layers). A bundle without a record predates it and keeps the four
# layers it was built with.
read_layers() {
    local f="${1}/layers"
    if [[ -f "$f" ]]; then
        { command -p grep -E '^[a-z-]+=on[[:space:]]*$' "$f" || true; } | sed 's/=on[[:space:]]*$//' | tr '\n' ' '
    else
        printf 'digest output-style stop-review'
    fi
}
has_layer() { case " $1 " in *" $2 "*) return 0 ;; *) return 1 ;; esac; }

# Output-style files in <dir> that the toolkit generated (recognised by the
# description line the installers write), one path per line.
toolkit_style_files() {
    local f
    for f in "${1}"/*.md; do
        [[ -f "$f" ]] || continue
        if command -p grep -q '^description: Writing style directive (' "$f"; then printf '%s\n' "$f"; fi
    done
    return 0
}
# Display names of those files, one per line.
toolkit_style_names() {
    local f
    toolkit_style_files "$1" | while IFS= read -r f; do
        sed -n 's/^name: //p' "$f" | head -1
    done
    return 0
}

# SHA-256 of a file with its trailing newlines removed, so that a deployed
# copy and its canonical compare equal despite packaging newlines.
norm_sha256() {
    [[ -f "$1" ]] || return 1
    if command -v shasum >/dev/null 2>&1; then
        printf '%s' "$(cat "$1")" | shasum -a 256 | cut -c1-64
    else
        printf '%s' "$(cat "$1")" | sha256sum | cut -c1-64
    fi
}

detect_json_engine() {
    if [[ -n "${JSON_TOOL_ENGINE:-}" ]]; then printf '%s' "$JSON_TOOL_ENGINE"; return; fi
    if python3 -c 'import json' >/dev/null 2>&1; then printf 'python3'; return; fi
    if [[ "$(uname -s)" == "Darwin" ]] && command -v osascript >/dev/null 2>&1; then printf 'osascript'; return; fi
    if command -v node >/dev/null 2>&1; then printf 'node'; return; fi
    printf ''
}

_JSON_TOOL_PY='
import json, os, re, sys
MARKER = "[writing-style-policy]"
OUR_FILES = ("style-digest.sh", "style-emoji-check.sh")
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
def ours(h):
    if not isinstance(h, dict):
        return False
    cmd = h.get("command")
    if isinstance(cmd, str) and any(f in cmd for f in OUR_FILES):
        return True
    return h.get("type") == "prompt" and str(h.get("prompt", "")).startswith(MARKER)
def purge(hooks):
    for ev in list(hooks):
        groups = hooks[ev]
        if not isinstance(groups, list):
            continue
        kept = []
        for g in groups:
            if not isinstance(g, dict) or not isinstance(g.get("hooks"), list):
                kept.append(g)
                continue
            hs = [h for h in g["hooks"] if not ours(h)]
            if hs:
                kept.append({**g, "hooks": hs})
        if kept:
            hooks[ev] = kept
        else:
            del hooks[ev]
def toolkit_styles():
    names = [n.strip() for n in os.environ.get("TOOLKIT_STYLES", "").split("\n") if n.strip()]
    style = os.environ.get("STYLE", "")
    if style:
        names.append(style)
    return set(names)
EMOJI_BMP = ((0x231A, 0x231B), (0x23E9, 0x23EC), (0x23F0, 0x23F0), (0x23F3, 0x23F3),
    (0x25FD, 0x25FE), (0x2614, 0x2615), (0x2648, 0x2653), (0x267F, 0x267F), (0x2693, 0x2693),
    (0x26A1, 0x26A1), (0x26AA, 0x26AB), (0x26BD, 0x26BE), (0x26C4, 0x26C5), (0x26CE, 0x26CE),
    (0x26D4, 0x26D4), (0x26EA, 0x26EA), (0x26F2, 0x26F3), (0x26F5, 0x26F5), (0x26FA, 0x26FA),
    (0x26FD, 0x26FD), (0x2705, 0x2705), (0x270A, 0x270B), (0x2728, 0x2728), (0x274C, 0x274C),
    (0x274E, 0x274E), (0x2753, 0x2755), (0x2757, 0x2757), (0x2795, 0x2797), (0x27B0, 0x27B0),
    (0x27BF, 0x27BF), (0x2B1B, 0x2B1C), (0x2B50, 0x2B50), (0x2B55, 0x2B55),
    (0x20E3, 0x20E3), (0xFE0F, 0xFE0F))
def is_emoji(cp):
    if 0x1F000 <= cp <= 0x1FAFF or 0x1FC00 <= cp <= 0x1FFFD or 0xE0020 <= cp <= 0xE007F:
        return True
    return any(a <= cp <= b for a, b in EMOJI_BMP)
RELEVANT = re.compile(r"\bgit\b(?:\s+-[cC]\s+\S+|\s+--?[\w-]+(?:=\S+)?)*\s+(?:commit|merge|tag)\b"
                      r"|\bgh\s+(?:pr\s+(?:create|edit|comment|review|merge)|api)\b")
FILEARG = re.compile(r"(?:^|\s)(?:-F|--file|--body-file|--input)(?:=|\s+)(\"[^\"]*\"|\x27[^\x27]*\x27|[^\s;&|]+)")
if op == "validate":
    need_settings_object(jloads(os.environ["EXISTING"])); sys.exit(0)
if op == "emoji-scan":
    d = jloads(os.environ.get("INPUT", ""))
    ti = d.get("tool_input") if isinstance(d, dict) else None
    cmd = ti.get("command") if isinstance(ti, dict) else None
    if not isinstance(cmd, str) or not RELEVANT.search(cmd):
        print("none"); sys.exit(0)
    cwd = d.get("cwd") if isinstance(d.get("cwd"), str) else ""
    texts = [cmd]
    for m in FILEARG.finditer(cmd):
        path = m.group(1).strip("\"\x27")
        if not path or path == "-":
            continue
        full = path if os.path.isabs(path) else os.path.join(cwd, path)
        try:
            with open(full, encoding="utf-8", errors="replace") as fh:
                texts.append(fh.read(1048576))
        except OSError:
            pass
    found = sorted({"U+%04X" % ord(c) for t in texts for c in t if is_emoji(ord(c))})
    if not found:
        print("none"); sys.exit(0)
    print("hit " + " ".join(found))
    print("\n".join(texts))
    sys.exit(0)
if op == "fragment":
    style = os.environ.get("STYLE", "")
    layers = set(os.environ.get("LAYERS", "").split())
    prompt = os.environ.get("PROMPT", "").strip()
    if not style:
        print("fragment requires a non-empty STYLE", file=sys.stderr); sys.exit(1)
    hooks = {}
    out = {}
    if "output-style" in layers:
        out["outputStyle"] = style
    if "digest" in layers:
        hooks["UserPromptSubmit"] = [{"hooks": [{"type": "command",
            "command": "\"__CS_HOOKS_DIR__/style-digest.sh\""}]}]
    if "stop-review" in layers:
        if not prompt:
            print("the stop-review layer requires a non-empty PROMPT", file=sys.stderr); sys.exit(1)
        if not prompt.startswith(MARKER):
            prompt = MARKER + " " + prompt
        hooks["Stop"] = [{"hooks": [{"type": "prompt", "prompt": prompt}]}]
    if "commit-emoji-check" in layers:
        hooks["PreToolUse"] = [{"matcher": "Bash", "hooks": [{"type": "command",
            "command": "\"__CS_HOOKS_DIR__/style-emoji-check.sh\""}]}]
    out["hooks"] = hooks
elif op == "merge":
    frag = jloads(os.environ["FRAGMENT"])
    out = need_settings_object(load_env("EXISTING", {}))
    if "outputStyle" in frag:
        out["outputStyle"] = frag["outputStyle"]
    elif out.get("outputStyle") in toolkit_styles():
        del out["outputStyle"]
    hooks = out.get("hooks", {})
    purge(hooks)
    for ev, groups in frag.get("hooks", {}).items():
        hooks.setdefault(ev, []).extend(groups)
    if hooks:
        out["hooks"] = hooks
    else:
        out.pop("hooks", None)
elif op == "strip":
    out = need_settings_object(load_env("EXISTING", {}))
    if out.get("outputStyle") in toolkit_styles():
        del out["outputStyle"]
    hooks = out.get("hooks", {})
    purge(hooks)
    if hooks:
        out["hooks"] = hooks
    else:
        out.pop("hooks", None)
else:
    sys.exit(2)
print(json.dumps(out, indent=2, ensure_ascii=False, allow_nan=False))
'

# Engine-neutral JS core: transform(op, env, readFile) -> string or null (validate).
_JSON_TOOL_JS_CORE='
const MARKER = "[writing-style-policy]";
const OUR_FILES = ["style-digest.sh", "style-emoji-check.sh"];
const EMOJI_BMP = [[0x231A,0x231B],[0x23E9,0x23EC],[0x23F0,0x23F0],[0x23F3,0x23F3],
    [0x25FD,0x25FE],[0x2614,0x2615],[0x2648,0x2653],[0x267F,0x267F],[0x2693,0x2693],
    [0x26A1,0x26A1],[0x26AA,0x26AB],[0x26BD,0x26BE],[0x26C4,0x26C5],[0x26CE,0x26CE],
    [0x26D4,0x26D4],[0x26EA,0x26EA],[0x26F2,0x26F3],[0x26F5,0x26F5],[0x26FA,0x26FA],
    [0x26FD,0x26FD],[0x2705,0x2705],[0x270A,0x270B],[0x2728,0x2728],[0x274C,0x274C],
    [0x274E,0x274E],[0x2753,0x2755],[0x2757,0x2757],[0x2795,0x2797],[0x27B0,0x27B0],
    [0x27BF,0x27BF],[0x2B1B,0x2B1C],[0x2B50,0x2B50],[0x2B55,0x2B55],
    [0x20E3,0x20E3],[0xFE0F,0xFE0F]];
const isEmoji = (cp) => (cp >= 0x1F000 && cp <= 0x1FAFF) || (cp >= 0x1FC00 && cp <= 0x1FFFD)
    || (cp >= 0xE0020 && cp <= 0xE007F) || EMOJI_BMP.some(([a, b]) => cp >= a && cp <= b);
const RELEVANT = /\bgit\b(?:\s+-[cC]\s+\S+|\s+--?[\w-]+(?:=\S+)?)*\s+(?:commit|merge|tag)\b|\bgh\s+(?:pr\s+(?:create|edit|comment|review|merge)|api)\b/;
const FILEARG = /(?:^|\s)(?:-F|--file|--body-file|--input)(?:=|\s+)("[^"]*"|\x27[^\x27]*\x27|[^\s;&|]+)/g;
function transform(op, env, readFile) {
    const loadEnv = (name, dflt) => {
        const v = env(name) || "";
        return v.trim() ? JSON.parse(v) : dflt;
    };
    const bad = (x) => typeof x !== "object" || x === null || Array.isArray(x);
    const needSettingsObject = (v) => {
        if (bad(v) || (v.hooks !== undefined && bad(v.hooks)))
            throw new Error("settings root (and any hooks key) must be a JSON object");
        return v;
    };
    const ours = (h) => {
        if (bad(h)) return false;
        if (typeof h.command === "string" && OUR_FILES.some(f => h.command.indexOf(f) !== -1)) return true;
        return h.type === "prompt" && String(h.prompt || "").startsWith(MARKER);
    };
    const purge = (hooks) => {
        for (const ev of Object.keys(hooks)) {
            const groups = hooks[ev];
            if (!Array.isArray(groups)) continue;
            const kept = [];
            for (const g of groups) {
                if (bad(g) || !Array.isArray(g.hooks)) { kept.push(g); continue; }
                const hs = g.hooks.filter(h => !ours(h));
                if (hs.length) kept.push(Object.assign({}, g, {hooks: hs}));
            }
            if (kept.length) hooks[ev] = kept; else delete hooks[ev];
        }
    };
    const toolkitStyles = () => {
        const names = (env("TOOLKIT_STYLES") || "").split("\n").map(s => s.trim()).filter(Boolean);
        const style = env("STYLE") || "";
        if (style) names.push(style);
        return names;
    };
    if (op === "validate") { needSettingsObject(JSON.parse(env("EXISTING"))); return null; }
    if (op === "emoji-scan") {
        const d = JSON.parse(env("INPUT") || "");
        const ti = bad(d) ? null : d.tool_input;
        const cmd = bad(ti) ? null : ti.command;
        if (typeof cmd !== "string" || !RELEVANT.test(cmd)) return "none";
        const cwd = typeof d.cwd === "string" ? d.cwd : "";
        const texts = [cmd];
        for (const m of cmd.matchAll(FILEARG)) {
            const p = m[1].replace(/^["\x27]|["\x27]$/g, "");
            if (!p || p === "-") continue;
            const full = p.startsWith("/") ? p : (cwd.replace(/\/$/, "") + "/" + p);
            const t = readFile(full);
            if (typeof t === "string") texts.push(t.slice(0, 1048576));
        }
        const found = new Set();
        for (const t of texts) for (const ch of t) {
            const cp = ch.codePointAt(0);
            if (isEmoji(cp)) found.add("U+" + cp.toString(16).toUpperCase().padStart(4, "0"));
        }
        if (!found.size) return "none";
        return "hit " + Array.from(found).sort().join(" ") + "\n" + texts.join("\n");
    }
    let out;
    if (op === "fragment") {
        const style = env("STYLE") || "";
        const layers = new Set((env("LAYERS") || "").split(/\s+/).filter(Boolean));
        let p = (env("PROMPT") || "").trim();
        if (!style) throw new Error("fragment requires a non-empty STYLE");
        const hooks = {};
        out = {};
        if (layers.has("output-style")) out.outputStyle = style;
        if (layers.has("digest"))
            hooks.UserPromptSubmit = [{hooks: [{type: "command",
                command: "\"__CS_HOOKS_DIR__/style-digest.sh\""}]}];
        if (layers.has("stop-review")) {
            if (!p) throw new Error("the stop-review layer requires a non-empty PROMPT");
            if (!p.startsWith(MARKER)) p = MARKER + " " + p;
            hooks.Stop = [{hooks: [{type: "prompt", prompt: p}]}];
        }
        if (layers.has("commit-emoji-check"))
            hooks.PreToolUse = [{matcher: "Bash", hooks: [{type: "command",
                command: "\"__CS_HOOKS_DIR__/style-emoji-check.sh\""}]}];
        out.hooks = hooks;
    } else if (op === "merge") {
        const frag = JSON.parse(env("FRAGMENT"));
        out = needSettingsObject(loadEnv("EXISTING", {}));
        if (frag.outputStyle !== undefined) out.outputStyle = frag.outputStyle;
        else if (toolkitStyles().includes(out.outputStyle)) delete out.outputStyle;
        const hooks = out.hooks || {};
        purge(hooks);
        for (const ev of Object.keys(frag.hooks || {}))
            hooks[ev] = (hooks[ev] || []).concat(frag.hooks[ev]);
        if (Object.keys(hooks).length) out.hooks = hooks; else delete out.hooks;
    } else if (op === "strip") {
        out = needSettingsObject(loadEnv("EXISTING", {}));
        if (toolkitStyles().includes(out.outputStyle)) delete out.outputStyle;
        const hooks = out.hooks || {};
        purge(hooks);
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
    const readFile = (p) => { const s = \$.NSString.stringWithContentsOfFileEncodingError(p, \$.NSUTF8StringEncoding, null); return s.isNil() ? null : ObjC.unwrap(s); };
    const r = transform(argv[0], env, readFile);
    return r === null ? \"\" : r;
}" "$op"
            ;;
        node)
            node -e "${_JSON_TOOL_JS_CORE}
const fs = require(\"fs\");
const readFile = (p) => { try { return fs.readFileSync(p, \"utf8\"); } catch (e) { return null; } };
const r = transform(process.argv[1], (n) => process.env[n] || \"\", readFile);
if (r !== null) console.log(r);" "$op"
            ;;
        *)
            echo "No JSON engine available (need python3, osascript, or node)." >&2
            return 2
            ;;
    esac
}
