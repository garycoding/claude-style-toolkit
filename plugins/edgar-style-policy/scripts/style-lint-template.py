#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Gary Frattarola
# SPDX-License-Identifier: MIT OR Apache-2.0
#
# TEMPLATE (toolkit file, licensed as above). When the style-author skill stages
# the deployed lint.py, it drops these SPDX header lines: the deployed hook is
# the user's private configuration, carrying the user's own banned-phrase list.
"""Stop hook: deterministic lint of the last assistant reply against the
mechanically checkable subset of a style directive.

Fill BANNED_PHRASES with the user's literal banned words and phrases
(case-insensitive substring match). Deterministic enforcement never
loses attention weight, so this list is the part of the style that
holds at any context length.

Reads the reply from the last_assistant_message input field (Stop hook
input since Claude Code v2.1.47); falls back to parsing the transcript.
Honors stop_hook_active to prevent revision loops. All failure paths
exit 0 — a lint bug must never wedge the session.
"""
import json
import re
import sys

# --- Filled in by the style-author skill ---------------------------------
BANNED_PHRASES = [
    # "game-changer",
    # "synergy",
]
CHECK_EMOJI = True            # U+1F300..U+1FAFF only; dingbats permitted
FLATTERY_OPENERS = (
    r"^\s*(great question|excellent question|great idea|"
    r"you'?re absolutely right|what a great)"
)
# --------------------------------------------------------------------------


def last_assistant_text(transcript_path):
    last = None
    try:
        with open(transcript_path, encoding="utf-8") as f:
            for line in f:
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if entry.get("type") != "assistant":
                    continue
                content = entry.get("message", {}).get("content", [])
                texts = [b.get("text", "") for b in content
                         if isinstance(b, dict) and b.get("type") == "text"]
                if texts:
                    last = "\n".join(texts)
    except OSError:
        return None
    return last


def main():
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)

    if data.get("stop_hook_active"):
        sys.exit(0)

    text = data.get("last_assistant_message")
    if not isinstance(text, str) or not text:
        text = last_assistant_text(data.get("transcript_path", ""))
    if not text:
        sys.exit(0)

    violations = []
    lowered = text.lower()

    for phrase in BANNED_PHRASES:
        if phrase.lower() in lowered:
            violations.append(f'banned phrase: "{phrase}"')

    if CHECK_EMOJI and re.search("[\U0001F300-\U0001FAFF]", text):
        violations.append("emoji present")

    if FLATTERY_OPENERS and re.search(FLATTERY_OPENERS, text, re.IGNORECASE):
        violations.append("flattery opener")

    if violations:
        print(json.dumps({
            "decision": "block",
            "reason": ("Style directive violation: " + "; ".join(violations)
                       + ". Revise the reply to comply with the writing-style"
                         " rules."),
        }))
    sys.exit(0)


if __name__ == "__main__":
    main()
