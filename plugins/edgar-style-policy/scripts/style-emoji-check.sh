#!/bin/bash
# SPDX-FileCopyrightText: 2026 Gary Frattarola
# SPDX-License-Identifier: MIT OR Apache-2.0
#
# PreToolUse hook (matcher: Bash) for edgar-style-policy: the commit and
# pull-request emoji check. Deployed beside style-json-tool.sh (a copy of
# json-tool.sh) by the installers when a style's layer record turns
# commit-emoji-check on.
#
# The rule it serves bars emoji used to communicate (to express or to
# decorate), not an emoji that is itself the subject under discussion.
# Telling the two apart is a judgement, so this script only establishes the
# fact and the model makes the judgement:
#   1. A command that records no message (not git commit/merge/tag, not gh
#      pr create/edit/comment/review/merge, not gh api) passes untouched.
#   2. If the command text, or a message file it names (-F, --file,
#      --body-file, --input), contains an emoji code point, the command is
#      refused once, with the code points named and the judgement asked for.
#   3. The same text submitted again passes: re-running the command
#      unchanged is the model's judgement that the emoji is mentioned, not
#      used. A fingerprint of the text is kept in the user's state directory.
# The check fails open: if no JSON engine is available or the input cannot
# be read, the command passes, so a broken check never blocks git.
# Stated limits: it cannot see text built from variables or command
# substitution, messages written by git hooks, aliases or scripts, MCP
# GitHub tools, or pull requests made in a desktop interface.

INPUT="$(cat)"
case "$INPUT" in
    *git*|*gh*) ;;
    *) exit 0 ;;
esac

HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=json-tool.sh
source "${HERE}/style-json-tool.sh" 2>/dev/null || exit 0
RESULT="$(INPUT="$INPUT" json_transform emoji-scan 2>/dev/null)" || exit 0
VERDICT="${RESULT%%$'\n'*}"
[[ "$VERDICT" == hit* ]] || exit 0

TEXT="${RESULT#*$'\n'}"
if command -v shasum >/dev/null 2>&1; then
    FP="$(printf '%s' "$TEXT" | shasum -a 256 | cut -c1-64)"
else
    FP="$(printf '%s' "$TEXT" | sha256sum | cut -c1-64)"
fi
[[ -n "$FP" ]] || exit 0

STATE="${XDG_STATE_HOME:-${HOME}/.local/state}/edgar-style-policy"
SEEN="${STATE}/emoji-seen"
mkdir -p "$STATE" 2>/dev/null || exit 0
if [[ -f "$SEEN" ]] && command -p grep -qxF "$FP" "$SEEN"; then
    # Second submission of the same text: the model judged the emoji to be
    # mentioned rather than used. Let it through and forget the fingerprint.
    command -p grep -vxF "$FP" "$SEEN" > "${SEEN}.tmp" 2>/dev/null
    mv -f "${SEEN}.tmp" "$SEEN" 2>/dev/null
    exit 0
fi
printf '%s\n' "$FP" >> "$SEEN"
tail -n 50 "$SEEN" > "${SEEN}.tmp" 2>/dev/null && mv -f "${SEEN}.tmp" "$SEEN" 2>/dev/null

CODEPOINTS="${VERDICT#hit }"
cat >&2 <<EOF
edgar-style-policy: the message this command would record contains emoji (${CODEPOINTS}).
Judge each one. If it expresses an idea or decorates the text, replace it with
words and run the corrected command. If it is itself the subject under
discussion, run the same command again unchanged; it will then pass.
EOF
exit 2
