---
name: style-maintain
description: Review, verify, troubleshoot, update, and remove an installed writing-style policy for Claude. Audits deployed files against the canonical directive, checks the live layers (CLAUDE.md, output style, digest hook, lint hook), diagnoses why a style is not being followed, checks for Claude Code platform drift, reworks the directive from new example documents and observed unwanted behaviors, redeploys to the installed tier, and supports uninstall or migration between tiers. Use when the user wants to check, fix, update, revise, re-verify, troubleshoot, uninstall, or move their writing style policy or style enforcement setup.
---

# Style-policy maintenance

You maintain a previously installed style policy (see the companion skill
`style-author` for initial creation). Work one finding or decision per
exchange; never change the user's directive without their verdict. The
canonical directive is the single source of truth — every deployed file is
generated from it, and deployed copies are never hand-edited.

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

Record the tier — later phases (redeploy, uninstall, migrate) branch on
it. Ask the user where the canonical (editable) copy of the directive
lives — typically a git repo. If the canonical file cannot be found, stop
and resolve that first: everything else is generated from it.

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

## Phase 4 — Troubleshooting: the style is not being followed

The most common reason to open this skill. Work the diagnostic tree in
order and stop at the first cause found:

1. **Stale session.** The output style and managed settings are fixed at
   session start. If the policy was just installed or changed, the
   current session predates it — have the user start a fresh session
   (`/clear` or restart) and recheck.
2. **Not actually active.** Run Phases 2–3. If the directive is not in
   context or the output style is not applied, the install is broken or
   incomplete — go to Phase 7 and redeploy.
3. **Wrong session type.** Cloud and web sessions are not reached by
   endpoint files — only server-managed settings deliver policy there.
   Confirm the user is in a local CLI, a desktop Code tab, or a desktop
   Cowork tab (all of which read the local tier), not a cloud session.
4. **Platform override or displacement.** Run Phase 5 — a plugin style
   with `force-for-plugin: true` overrides `outputStyle`, and
   server-managed settings from an org admin console silently displace
   the file-based managed tier.
5. **Digest or lint gap.** If the tone drifts only in long sessions, the
   digest may be stale (Phase 2, check 2). If a banned phrase slips
   through, confirm the lint contains it and that the turn did not end in
   an API error (the lint does not run on `StopFailure` turns).

## Phase 5 — Platform-health check

Run this after any Claude Code upgrade, or as step 4 of troubleshooting.
The policy depends on Claude Code mechanics that change between versions:

1. **Managed source** (managed tier): run `/status` and confirm the
   active managed source is the file-based enterprise settings. If it
   reads as remote or server-managed, an org admin console has displaced
   the local file tier, which is now inert.
2. **Output-style support**: confirm `outputStyle` is still honored (ask
   Claude whether the named style is active). The switching command has
   changed across versions; the setting is the supported path, but
   re-verify the layer after a major upgrade.
3. **Plugin override**: check enabled plugins for an output style with
   `force-for-plugin: true`, which outranks `outputStyle`.
4. **Hook execution**: confirm both hooks still fire (Phase 3). Note that
   `--safe-mode` starts a session with all hooks disabled.

Report which layers are intact and which need attention; a failure here
usually routes to Phase 7 (redeploy) or is outside the policy's control
(server-managed displacement, which the user resolves with their admin).

## Phase 6 — Rework the directive

Whether the user came to revise deliberately or arrived here from
troubleshooting, gather evidence before changing anything. Proactively
ask for both:

- **New example documents**: any recent pieces whose voice is right (or
  wrong). Read them and mine the same signals as initial authoring —
  register, diction, sentence complexity, formatting, how claims are
  hedged. New exemplars are the strongest input to a revision.
- **Unwanted behaviors they have seen**: specific things Claude has
  written that they did not want. Each concrete irritation becomes a
  rule, a tightened test, or an added banned phrase — this is the most
  valuable maintenance input, because it targets real failures rather
  than hypothetical ones.

Then rework the directive by the style-author method: the
rule/test/example-pair template, the calibration principle (additions
must pay for themselves; trimming counts as much as adding), one change
per verdict. A banned-phrase-only change is a common, low-stakes case —
it updates the Diction section and the lint's `BANNED_PHRASES`, and needs
a redeploy of the lint but no digest change. For a broader revision,
offer a fresh-eyes pass: spawn the reviewer lenses from `style-author`'s
`resources/review-lenses.md` against the reworked directive and present
surviving findings ranked.

Present the reworked directive and iterate — review findings or freeform
edits, one decision per exchange — until the user is pleased with the
result. Do not redeploy until they confirm the document is right.

## Phase 7 — Redeploy and re-verify

After any canonical edit, in order:

1. **Review the digest** against the reworked directive (Phase 2,
   check 2). Mandatory — the digest is the one artifact that drifts
   silently.
2. **Stage** into an ephemeral `mktemp -d` directory: `canonical.md`
   (no license header), `digest.sh` and `lint.py` (from the templates,
   SPDX headers dropped, banned-phrase list refreshed).
3. **Redeploy to the installed tier** (from Phase 1):
   - *User tier*: run `${CLAUDE_PLUGIN_ROOT}/scripts/install-user.sh
     <staging-dir> "<Style Name>"` directly.
   - *Managed tier*: run
     `${CLAUDE_PLUGIN_ROOT}/scripts/build-managed-installer.sh
     <staging-dir> "<Style Name>"` to assemble the same self-contained
     `~/install_claude_writing_style.sh`, then have the user run
     `sudo ~/install_claude_writing_style.sh`. It writes the policy
     root-owned and deletes itself on success.
4. **Prune backups** if the user wants: each redeploy leaves a
   timestamped `managed-settings.json.bak` (managed) or
   `settings.json.bak` (user); offer to remove old ones, keeping the most
   recent.
5. **Delete the staging directory**, have the user start a fresh session,
   and repeat Phase 3. Record what changed and what was verified.

## Phase 8 — Uninstall or migrate tiers

**Uninstall.** Removing deployed copies never touches the canonical repo.

- *Managed tier*: `sudo rm -rf` the managed directory (macOS
  `/Library/Application Support/ClaudeCode`, Linux `/etc/claude-code`).
  If `chflags schg` hardening was applied on macOS, clear it first with
  `sudo chflags noschg <file>`.
- *User tier*: remove `~/.claude/writing-style.md`, the
  `@~/.claude/writing-style.md` import line from `~/.claude/CLAUDE.md`,
  the output-style file, and the two hook scripts; then remove the
  `outputStyle` key and the two hook entries from `~/.claude/settings.json`
  (restore from the `.bak` written at install, or edit them out). Back up
  `settings.json` before editing.

**Migrate between tiers.** Deploy the target tier first, verify it, then
remove the old one — never leave the machine with no policy mid-migration.

- *User → managed*: run `build-managed-installer.sh` from the canonical,
  have the user run the sudo installer, verify (Phase 3), then uninstall
  the user-tier pieces above.
- *Managed → user*: run `install-user.sh` from the canonical, verify,
  then `sudo rm -rf` the managed directory.

Confirm the tier recorded in Phase 1 is updated to the new one for any
later maintenance.
