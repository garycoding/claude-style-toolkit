---
name: style-maintain
description: Review, verify, and update an installed writing-style policy — audit deployed files against the canonical directive, check the live layers (CLAUDE.md, output style, digest hook, lint hook), guide edits to the directive, regenerate the digest, and redeploy. Use when the user wants to check, update, revise, re-verify, or troubleshoot their writing style policy or style enforcement setup.
---

# Style-policy maintenance

You are auditing and updating a previously installed style policy (see
the companion skill `style-author` for initial creation). Work one
finding or decision per exchange; never change the user's directive
without their verdict.

## Phase 1 — Locate the installation

Determine which tier is installed and where the canonical file lives:

- **Managed tier**: macOS `/Library/Application Support/ClaudeCode/`,
  Linux `/etc/claude-code/` — look for `CLAUDE.md`,
  `managed-settings.json`, `hooks/style-digest.sh`, `hooks/style-lint.py`,
  `.claude/output-styles/*.md`.
- **User tier**: `~/.claude/writing-style.md`, an `@~/.claude/writing-style.md`
  import line in `~/.claude/CLAUDE.md`, `~/.claude/output-styles/*.md`,
  `~/.claude/hooks/`, and `outputStyle` + hook entries in
  `~/.claude/settings.json`.

Ask the user where the canonical (editable) copy of the directive lives
— typically a git repo. If the canonical file cannot be found, stop and
resolve that first: everything else is generated from it.

## Phase 2 — Integrity audit

Report each check as pass/fail with the evidence:

1. **Drift**: `diff` the deployed CLAUDE.md and the output-style body
   against the canonical file. Any difference means a deploy was missed
   after an edit — the fix is redeploy, never hand-editing deployed
   copies.
2. **Digest review**: read the digest text in the deployed
   `style-digest.sh` against the current directive. The digest is
   hand-maintained and is the one artifact that can drift semantically:
   check that every rule it states is still in the directive and that no
   high-frequency rule added since is missing from it.
3. **Ownership** (managed tier): the managed directory and every file in
   it should be root-owned. A user-owned parent directory lets files be
   deleted without elevation.
4. **Settings**: `outputStyle` names the installed style; both hook
   entries present and pointing at existing executable files.

## Phase 3 — Live verification

In the current session (or instruct the user to run these in a fresh
one): confirm the directive is present in context and the output style
is active — Claude can verify both from its own context; confirm the
digest line arrived with the user's prompt; test the lint by running the
deployed `style-lint.py` against a synthetic violating input
(`{"last_assistant_message": "<text violating a banned rule>",
"stop_hook_active": false}` on stdin) and confirming it emits a block
decision. If the user works in a desktop app, have them repeat the
context check once in a Cowork tab session.

## Phase 4 — Directive updates (on request)

For content changes, follow the style-author method: the rule/test/
example-pair template, the calibration principle (additions must pay
for themselves), one change per verdict. For a periodic health check,
offer a mini fresh-eyes pass: spawn the reviewer lenses from
`style-author`'s `resources/review-lenses.md` against the current
directive and present surviving findings ranked.

## Phase 5 — Redeploy and re-verify

After any canonical edit: review the digest (Phase 2, check 2 — this is
mandatory, not optional), rebuild the staging directory, rerun the
installer for the installed tier (user tier directly; managed tier by
printing the `sudo` command for the user), have the user start a fresh
session, and repeat Phase 3. Record what changed and what was verified.
