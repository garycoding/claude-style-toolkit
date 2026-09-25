#!/bin/bash
# SPDX-FileCopyrightText: 2026 Gary Frattarola
# SPDX-License-Identifier: MIT OR Apache-2.0
#
# Assembles a single, self-contained managed-tier installer and writes it to
# the user's home directory as install_claude_writing_style.sh. The directive,
# the files of every layer the style's record turns on, the settings fragment,
# and the JSON engine library are embedded inline — human-readable, so the
# sudo script can be inspected before running. The emitted installer brings
# the OS managed directory exactly into line with the layer record, writes
# the policy root-owned, and deletes itself.
#
# Layers (from <staging-dir>/layers, "<layer>=on" lines; a folder without a
# record keeps the original four): the directive as the managed CLAUDE.md is
# always deployed; digest, output-style (with output-style-coding for
# keep-coding-instructions), stop-review, and commit-emoji-check are
# deployed when on and removed when off.
#
# The managed CLAUDE.md is protected: before it is written, an existing one
# that is not the toolkit's own (it matches neither the sidecar record
# .edgar-style-policy nor any canonical in the style library) is kept as
# CLAUDE.md.pre-edgar-style-policy, which the uninstaller restores.
#
# Settings handling in the emitted installer, in order of preference:
#   1. Any JSON engine on the target machine (python3, osascript on macOS,
#      or node — identical on both OSes, via the inlined json-tool.sh) ->
#      the managed-settings.json is brought into line with the fragment
#      (other managed settings preserved; toolkit entries the record lacks
#      removed).
#   2. No engine, but a pre-merged settings file was supplied at build time
#      (the guiding model reads the world-readable managed-settings.json,
#      merges the fragment itself, and validates the result) -> the emitted
#      installer writes that pre-merged content (backup first).
#   3. Neither -> backup and replace with the bare fragment, and say so.
#
# Usage: build-managed-installer.sh <staging-dir> [style-name] [output-path] [premerged-settings-file]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=json-tool.sh
source "${SCRIPT_DIR}/json-tool.sh"

STAGING="${1:?Usage: build-managed-installer.sh <staging-dir> [style-name] [output-path] [premerged-settings-file]}"
STYLE_NAME="${2:-Writing Style}"
OUTPUT="${3:-${HOME}/install_claude_writing_style.sh}"
PREMERGED="${4:-}"
case "$STYLE_NAME" in
    *$'\n'*)   echo "Style name must not contain newlines." >&2; exit 1 ;;
    \"*|\'*)   echo "Style name must not start with a quote." >&2; exit 1 ;;
esac
[[ -n "${STYLE_NAME// /}" ]] || { echo "Style name must not be empty." >&2; exit 1; }
SLUG=$(printf '%s' "$STYLE_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//')
[[ -n "$SLUG" ]] || SLUG="writing-style"
LAYERS="$(read_layers "$STAGING")"

REQUIRED=(canonical.md)
has_layer "$LAYERS" digest && REQUIRED+=(digest.sh)
has_layer "$LAYERS" stop-review && REQUIRED+=(review-prompt.txt)
for f in "${REQUIRED[@]}"; do
    [[ -f "${STAGING}/${f}" ]] || { echo "Missing ${STAGING}/${f}" >&2; exit 1; }
done
[[ -n "$(detect_json_engine)" ]] || {
    echo "This builder needs a JSON engine (python3, osascript, or node)." >&2
    exit 1
}

# Collision guard: payloads must not contain the heredoc sentinels wrapping them.
guard() { grep -qF "$2" "$1" && { echo "Payload $1 contains sentinel $2; aborting." >&2; exit 1; } || true; }
GUARDED_FILES=("${SCRIPT_DIR}/json-tool.sh" "${SCRIPT_DIR}/style-emoji-check.sh")
for f in "${REQUIRED[@]}"; do GUARDED_FILES+=("${STAGING}/${f}"); done
[[ -n "$PREMERGED" ]] && GUARDED_FILES+=("$PREMERGED")
for s in __CS_DIRECTIVE_EOF__ __CS_STYLE_EOF__ __CS_DIGEST_EOF__ __CS_FRAG_EOF__ \
         __CS_PREMERGED_EOF__ __CS_EMOJI_EOF__ __CS_JSONTOOL_EOF__; do
    for f in "${GUARDED_FILES[@]}"; do guard "$f" "$s"; done
done
# The substitution placeholder is reserved too — in staged content (not the
# pre-merged settings, which legitimately carry it) it would be rewritten
# into a filesystem path mid-text at run time.
for f in "${REQUIRED[@]}"; do guard "${STAGING}/${f}" "__CS_HOOKS_DIR__"; done
if [[ -n "$PREMERGED" ]]; then
    EXISTING="$(cat "$PREMERGED")" json_transform validate >/dev/null || {
        echo "Pre-merged settings file is not valid JSON: $PREMERGED" >&2; exit 1; }
fi

# Hashes of every canonical in the style library: an existing managed
# CLAUDE.md that matches one of them is the toolkit's own (an install that
# predates the sidecar record), not a foreign file to preserve.
LIBRARY="$(cd "${STAGING}/.." && pwd)"
OURS_SHAS=""
for c in "${LIBRARY}"/*/canonical*; do
    [[ -f "$c" ]] && OURS_SHAS+="$(norm_sha256 "$c") "
done

# Build the settings fragment at build time (engine-agnostic): valid JSON with
# the review prompt safely encoded; the hooks path is a placeholder
# substituted per-OS at run time.
PROMPT=""
has_layer "$LAYERS" stop-review && PROMPT="$(cat "${STAGING}/review-prompt.txt")"
FRAGMENT="$(STYLE="$STYLE_NAME" LAYERS="$LAYERS" PROMPT="$PROMPT" json_transform fragment)"

{
    cat <<'HDR'
#!/bin/bash
# Self-contained managed-tier installer for a Claude writing-style policy.
# Generated by claude-style-toolkit. Run once, then it deletes itself:
#     sudo ~/install_claude_writing_style.sh
# Root-owned policy is written to the OS managed directory. Safe to read first.
set -euo pipefail
if [[ $EUID -ne 0 ]]; then echo "Run with sudo: sudo \"$0\"" >&2; exit 1; fi
TARGET_USER="${SUDO_USER:?Run via sudo from your normal account, not a root shell}"

# --- inlined json-tool.sh (engine dispatch: python3 / osascript / node) ---
HDR
    cat "${SCRIPT_DIR}/json-tool.sh"
    printf -- '# --- end json-tool.sh ---\n'
    printf 'STYLE_NAME=%q\nSLUG=%q\nLAYERS=%q\nOURS_SHAS=%q\n' "$STYLE_NAME" "$SLUG" "$LAYERS" "$OURS_SHAS"
    cat <<'BODY1'
case "$(uname -s)" in
    Darwin) MANAGED_DIR="/Library/Application Support/ClaudeCode"; GROUP="wheel" ;;
    Linux)  MANAGED_DIR="/etc/claude-code"; GROUP="root" ;;
    *) echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac
HOOKS_DIR="${MANAGED_DIR}/hooks"
STYLE_DIR="${MANAGED_DIR}/.claude/output-styles"
CM="${MANAGED_DIR}/CLAUDE.md"
SIDECAR="${MANAGED_DIR}/.edgar-style-policy"
STAMP="$(date +%Y%m%d%H%M%S).$$"
mkdir -p "$HOOKS_DIR" "$STYLE_DIR"
# Style names the toolkit deployed before this run, read before any file changes.
TOOLKIT_STYLES="$(toolkit_style_names "$STYLE_DIR")"

# Protect a managed CLAUDE.md that is not the toolkit's own.
if [[ -f "$CM" ]]; then
    H="$(norm_sha256 "$CM")"
    OURS=0
    if [[ -f "$SIDECAR" ]] && command -p grep -qx "sha256=${H}" "$SIDECAR"; then OURS=1; fi
    for k in $OURS_SHAS; do if [[ "$k" == "$H" ]]; then OURS=1; fi; done
    if [[ $OURS -eq 0 ]]; then
        if [[ ! -e "${CM}.pre-edgar-style-policy" ]]; then
            cp -p "$CM" "${CM}.pre-edgar-style-policy"
            echo "Kept the existing managed CLAUDE.md as CLAUDE.md.pre-edgar-style-policy (restored on uninstall)."
        else
            cp -p "$CM" "${CM}.bak.${STAMP}"
            echo "Backed up the existing managed CLAUDE.md as CLAUDE.md.bak.${STAMP}."
        fi
    fi
fi
BODY1
    # Managed CLAUDE.md (directive verbatim).
    printf 'cat > "${CM}" <<'\''__CS_DIRECTIVE_EOF__'\''\n'
    cat "${STAGING}/canonical.md"
    printf '\n__CS_DIRECTIVE_EOF__\n'
    printf 'printf '\''slug=%%s\\nsha256=%%s\\n'\'' "$SLUG" "$(norm_sha256 "$CM")" > "$SIDECAR"\n'
    # Output style: every toolkit-generated file removed; this style's written if on.
    printf 'toolkit_style_files "$STYLE_DIR" | while IFS= read -r f; do rm -f "$f"; done\n'
    if has_layer "$LAYERS" output-style; then
        printf 'cat > "${STYLE_DIR}/${SLUG}.md" <<'\''__CS_STYLE_EOF__'\''\n'
        printf -- '---\nname: %s\ndescription: Writing style directive (managed; do not edit)\n' "$STYLE_NAME"
        has_layer "$LAYERS" output-style-coding && printf 'keep-coding-instructions: true\n'
        printf -- '---\n\n'
        cat "${STAGING}/canonical.md"
        printf '\n__CS_STYLE_EOF__\n'
    fi
    # Digest hook.
    if has_layer "$LAYERS" digest; then
        printf 'cat > "${HOOKS_DIR}/style-digest.sh" <<'\''__CS_DIGEST_EOF__'\''\n'
        cat "${STAGING}/digest.sh"
        printf '\n__CS_DIGEST_EOF__\n'
        printf 'chmod 0755 "${HOOKS_DIR}/style-digest.sh"\n'
    else
        printf 'rm -f "${HOOKS_DIR}/style-digest.sh"\n'
    fi
    # Commit and pull-request emoji check, with its JSON engine library.
    if has_layer "$LAYERS" commit-emoji-check; then
        printf 'cat > "${HOOKS_DIR}/style-emoji-check.sh" <<'\''__CS_EMOJI_EOF__'\''\n'
        cat "${SCRIPT_DIR}/style-emoji-check.sh"
        printf '__CS_EMOJI_EOF__\n'
        printf 'cat > "${HOOKS_DIR}/style-json-tool.sh" <<'\''__CS_JSONTOOL_EOF__'\''\n'
        cat "${SCRIPT_DIR}/json-tool.sh"
        printf '__CS_JSONTOOL_EOF__\n'
        printf 'chmod 0755 "${HOOKS_DIR}/style-emoji-check.sh"; chmod 0644 "${HOOKS_DIR}/style-json-tool.sh"\n'
    else
        printf 'rm -f "${HOOKS_DIR}/style-emoji-check.sh" "${HOOKS_DIR}/style-json-tool.sh"\n'
    fi
    # Settings fragment (built and validated at build time).
    printf 'FRAGMENT=$(cat <<'\''__CS_FRAG_EOF__'\''\n'
    printf '%s\n' "$FRAGMENT"
    printf '__CS_FRAG_EOF__\n)\n'
    # Optional pre-merged settings (model-merged at build time, validated).
    if [[ -n "$PREMERGED" ]]; then
        printf 'PREMERGED=$(cat <<'\''__CS_PREMERGED_EOF__'\''\n'
        cat "$PREMERGED"
        printf '\n__CS_PREMERGED_EOF__\n)\n'
    else
        printf 'PREMERGED=""\n'
    fi
    cat <<'BODY2'
FRAGMENT="${FRAGMENT//__CS_HOOKS_DIR__/${HOOKS_DIR}}"
[[ -n "$PREMERGED" ]] && PREMERGED="${PREMERGED//__CS_HOOKS_DIR__/${HOOKS_DIR}}"

MS="${MANAGED_DIR}/managed-settings.json"
ENGINE="$(detect_json_engine)"
EXISTING=""
[[ -f "$MS" ]] && EXISTING="$(cat "$MS")"
if [[ -n "$ENGINE" ]] && MERGED="$(FRAGMENT="$FRAGMENT" EXISTING="$EXISTING" STYLE="$STYLE_NAME" \
        TOOLKIT_STYLES="$TOOLKIT_STYLES" json_transform merge 2>/dev/null)"; then
    # Merge path: preserve any other managed settings; bring our own entries
    # exactly into line with the layer record.
    [[ -f "$MS" ]] && cp "$MS" "${MS}.bak.${STAMP}"
    printf '%s\n' "$MERGED" > "$MS"
    echo "Merged policy into managed-settings.json (engine: ${ENGINE}; other managed settings preserved)."
elif [[ -n "$PREMERGED" ]]; then
    # No engine, or the existing file is unusable: use the model's build-time merge.
    [[ -f "$MS" ]] && cp "$MS" "${MS}.bak.${STAMP}"
    printf '%s\n' "$PREMERGED" > "$MS"
    echo "Wrote pre-merged managed-settings.json (model-merged at build time; backup kept)."
else
    # Last resort: back up any existing file and write our fragment whole.
    if [[ -f "$MS" ]]; then
        cp "$MS" "${MS}.bak.${STAMP}"
        echo "Could not merge (no JSON engine, or the existing managed-settings.json is"
        echo "not a valid JSON object) and no pre-merged settings were supplied:"
        echo "backed up the existing file and replaced it."
    fi
    printf '%s\n' "$FRAGMENT" > "$MS"
fi

# Root-own the whole tree, then set file modes.
chown -R "root:${GROUP}" "$MANAGED_DIR"
chmod 0644 "$CM" "$MS" "$SIDECAR"
[[ -f "${STYLE_DIR}/${SLUG}.md" ]] && chmod 0644 "${STYLE_DIR}/${SLUG}.md"

echo "Installed (managed tier) to ${MANAGED_DIR} for style: ${STYLE_NAME}"
echo "Layers on: CLAUDE.md ${LAYERS}"
echo "Fully quit and restart Claude Code (a /clear is not enough), then verify:"
echo "  1. Ask Claude whether the managed CLAUDE.md with the directive is in its context."
echo "  2. Confirm the digest line arrives with each prompt, if the digest layer is on."
echo "  3. A commit whose message carries an emoji is refused once, if that check is on."

SELF="$0"
rm -f "$SELF" && echo "Removed installer: $SELF"
BODY2
} > "$OUTPUT"
chmod 0755 "$OUTPUT"

echo "Wrote self-contained installer: $OUTPUT"
echo "Have the user run, in a terminal:  sudo \"$OUTPUT\""
echo "It writes the policy root-owned and deletes itself on success."
