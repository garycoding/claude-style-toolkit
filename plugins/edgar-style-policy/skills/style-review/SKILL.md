---
name: style-review
description: Review a draft against the active edgar writing-style directive before it leaves the machine (a pull-request description, a commit message, a document or page to be published, an email) and report every departure with its location and a rewrite. Use only when the user asks for a style review of a specific draft.
disable-model-invocation: true
---

# Style review of a draft

You review one draft, on request, against the writing-style directive that
is active on this machine, and report what departs from it. This replaces
the review hook the toolkit once installed on every reply: that hook ran a
small model after each reply was already on screen, blocked on grounds its
own prompt excluded, and forced visible rewrites. Here the judgement is
yours, made on the whole draft with the directive in full, and only when
the user asks.

## Phase 1 — Find the directive

The directive is already in your context if a policy is installed: the
managed CLAUDE.md (macOS `/Library/Application Support/ClaudeCode/CLAUDE.md`,
Linux `/etc/claude-code/CLAUDE.md`) or `~/.claude/writing-style.md` imported
from `~/.claude/CLAUDE.md`. Read the deployed file itself rather than
relying on memory of it, so the review uses the exact current wording. Name
the style by matching the deployed file against the library folders under
`~/.claude/edgar-style-policies/*/canonical.md` (compare after normalising
trailing blank lines). If no policy is installed, say so and stop.

## Phase 2 — Identify the draft

The user names the draft: a file path, a pull request or commit to be
created (read the text you are about to use), pasted text, or "your last
reply". If it is unclear which text is meant, ask once. Note the draft's
kind and audience, since the directive's scope section may treat them
differently (code artifacts such as commit messages follow the repository's
conventions except where the directive says a rule applies to them too).

## Phase 3 — Review

Read the draft in full against every section of the directive, not a
checklist of banned words. For each departure, record:

- where it is (a line number, or a short quotation of the passage);
- which rule it departs from, named by the directive's own section;
- a rewrite of that passage that satisfies the rule and keeps the meaning.

Apply the directive's own distinctions with judgement. A banned word or an
emoji that is itself the subject under discussion is mentioned, not used,
and is not a departure. A term of art is not an idiom. A literal use is not
a figurative one. When a passage is borderline, say why in one line and
give the user the choice rather than counting it as a fault.

Do not report matters the directive does not govern, and do not rewrite
the draft wholesale. If the draft has no departures, say so plainly.

## Phase 4 — Report and apply

Present the departures most consequential first, then ask whether to apply
the rewrites. Apply only what the user accepts, to the file or the text in
question, and show the final version of any passage you changed. Nothing
is published, committed or sent by this skill; that remains the user's
decision or the next step of the task in hand.
