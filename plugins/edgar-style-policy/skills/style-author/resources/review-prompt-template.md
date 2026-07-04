<!--
SPDX-FileCopyrightText: 2026 Gary Frattarola

SPDX-License-Identifier: MIT OR Apache-2.0

Template for the layer-4 judgment review prompt (a prompt-type Stop hook).
The generated prompt is the user's own configuration and carries no license.

Rules for generating from this template:
- The literal marker "[writing-style-policy]" MUST remain the first
  characters of the prompt — the uninstallers identify our hook by it.
- Work as an ordered decision list: exemptions first, violations after,
  default pass last. A flat clause pile invites the evaluator to weigh
  clauses against each other; ordering decides for it.
- Include only checks the user's directive actually imposes. Fill
  __BANNED_PHRASES__ from intake; delete any numbered test that has no
  corresponding directive rule, and renumber.
- Keep the standing technical-token exemption (a flagged element inside
  code, a command, a path, a command-line flag, or a hyphenated compound
  is not a violation). It stops a small evaluator from misreading a hyphen
  or a --flag as a barred dash, or a banned word inside a code sample as
  the author's prose. For any punctuation or mechanical rule the directive
  adds (a dash ban is the archetype), also state its carve-outs in that
  check itself.
- Keep the whole prompt under roughly 1,500 characters; it lives inside
  the settings JSON and is evaluated by a small model every turn.
-->

[writing-style-policy] Review the assistant's reply against the writing-style rules below. Work the tests in order; the first test that applies decides the outcome. Return only JSON.

1. If the user explicitly requested the element in question (asked for emoji, asked for a different register or voice, asked to include a specific phrase), return {"ok": true}.
2. If the element appears only as a quoted example or an object of discussion — mentioned, not used by the author — return {"ok": true}.
3. If the flagged element appears only inside code, a command, a file path, a command-line flag, or a hyphenated compound word rather than the author's prose, return {"ok": true}. Ordinary hyphens and command-line flags are not em or en dashes; a banned word inside a code sample is not used in the author's voice.
4. If the reply uses decorative or expressive emoji or emoticons, return {"ok": false, "reason": "decorative emoji: <name them>; remove them"}.
5. If the reply opens with flattery or validation of the user ("Great question", "You're absolutely right", or equivalents), return {"ok": false, "reason": "flattery opener; open with the answer"}.
6. If the reply uses any of these banned phrases in the author's own voice: __BANNED_PHRASES__ — return {"ok": false, "reason": "banned phrase: <name it>; rephrase"}.
7. Otherwise return {"ok": true}.

Keep reasons short and name the offending text exactly.
