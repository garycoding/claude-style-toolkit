---
name: style-maintain
description: Review, verify, troubleshoot, and update an installed writing-style policy for Claude. Audits deployed files against the canonical directive, checks the live layers (CLAUDE.md, output style, digest hook, judgment-review hook), diagnoses why a style is not being followed, checks for Claude Code platform drift, reworks the directive from new example documents and observed unwanted behaviors, redeploys to the installed tier, and migrates between tiers. Use when the user wants to check, fix, update, revise, re-verify, troubleshoot, or move (migrate) their writing style policy or style enforcement setup. For removing a policy, use the style-uninstall skill instead.
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
  `managed-settings.json` (containing `outputStyle`, a digest command
  hook, and a Stop prompt hook whose prompt starts with
  `[writing-style-policy]`), `hooks/style-digest.sh`, and
  `.claude/output-styles/*.md`.
- **User tier**: `~/.claude/writing-style.md`, an `@~/.claude/writing-style.md`
  import line in `~/.claude/CLAUDE.md`, `~/.claude/output-styles/*.md`,
  `~/.claude/hooks/style-digest.sh`, and `outputStyle` + the digest and
  marker-tagged review hooks in `~/.claude/settings.json`. Note that
  `~/.claude/writing-style.md` is a deployed copy generated from the
  canonical, not the canonical itself — never hand-edit it.

Record the tier — later phases (redeploy, migrate) branch on it. Ask the
user where the canonical (editable) copy of the directive lives —
`VERIFIED.md` beside it records the style name, tier, and scenarios. If
it cannot be found, offer to seed a new canonical from the deployed
directive copy (`~/.claude/writing-style.md` on the user tier,
`<managed dir>/CLAUDE.md` on the managed tier), which is identical to
the canonical body up to a trailing newline; note that this loses any
prior git history. Do not proceed with edits until a canonical exists —
everything is generated from it.

**The style library.** Authored styles are stored as deployable bundles,
one folder per style, under `~/.claude/edgar-style-policies/<slug>/`
(`canonical.md`, `digest.sh`, `review-prompt.txt`, `VERIFIED.md`). The set
of stored styles is those folders; the ACTIVE style is whichever the live
`outputStyle` names. For a style in the library, treat its folder's
`canonical.md` as the editable source; if the user keeps a separate repo
master, `VERIFIED.md` records the path and the two must be kept in step.
Switching the active style among stored ones belongs to the `style-switch`
skill; this skill audits, reworks, and redeploys a style, refreshing its
library bundle when it does.

## Phase 2 — Integrity audit

Report each check as pass/fail with the evidence:

1. **Drift**: diff every deployed copy of the directive against the
   canonical. On the managed tier that is `<managed dir>/CLAUDE.md`; on
   the user tier it is `~/.claude/writing-style.md` (the deployed
   `~/.claude/CLAUDE.md` holds only the `@import` line, not the directive
   body — do not diff it). On both tiers also diff the output-style
   body, stripping its leading YAML frontmatter (everything through the
   second `---`) first. Compare after normalizing boundary blank lines:
   a single leading/trailing blank-line difference is deploy packaging
   (heredoc and frontmatter separators), not drift. Any remaining
   difference means a deploy was missed after an edit — the fix is
   redeploy, never hand-editing deployed copies.
2. **Condensation review**: the policy carries two hand-maintained
   condensations of the directive, and both drift silently. Read the
   digest text in the deployed `style-digest.sh` against the current
   directive; read the review prompt (the marker-tagged Stop prompt hook
   in the tier's settings file) against it likewise. Check that every
   rule they state is still in the directive and that no high-frequency
   rule added since is missing from them.
3. **Ownership** (managed tier): the managed directory and every file in
   it should be root-owned. A user-owned parent directory lets files be
   deleted without elevation.
4. **Settings**: `outputStyle` names the installed style; the digest
   command hook points at an existing executable file; exactly one
   marker-tagged review prompt hook is present.
5. **Library bundle** (if the active style is in the library): its folder
   `~/.claude/edgar-style-policies/<slug>/` should hold `canonical.md`,
   `digest.sh`, and `review-prompt.txt` matching the live deployment (after
   normalizing boundary blank lines). That folder is what `style-switch`
   redeploys, so a divergence means switching away and back would silently
   change the policy; the fix is to refresh the bundle (Phase 7), never to
   hand-edit deployed copies.

## Phase 3 — Live verification

In the current session (or instruct the user to run these in a fresh
one): confirm the directive is present in context and the output style
is active — Claude can verify both from its own context; confirm the
digest line arrived with the user's prompt; confirm the review hook is
registered (Phase 2, check 4). To test the review hook's judgment
without waiting for a live violation, use the sandbox method from
`style-author` Phase 6: a throwaway settings file carrying only the
review prompt hook, probed with `claude -p --settings <file>` on one
clear-violation case and one mention case. If the user works in a
desktop app, have them repeat the context check once in a Cowork tab
session.

## Phase 4 — Troubleshooting: the style is not being followed

The most common reason to open this skill. Work the diagnostic tree in
order and stop at the first cause found:

1. **Stale session.** The output style and managed settings are fixed at
   session start. If the policy was just installed or changed, the
   current session predates it — have the user fully quit and restart
   Claude Code (`/clear` alone does not reload the output style or managed
   settings; it only clears the transcript) and recheck.
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
5. **Condensation gap or judgment failure.** If the tone drifts only in
   long sessions, the digest may be stale (Phase 2, check 2). If a
   banned element slips through, check that the review prompt names it
   and that the turn did not end in an API error (Stop hooks do not run
   on `StopFailure` turns). If the review hook blocks things it should
   not (over-blocking), the review prompt's ordering or wording needs
   tightening — exemptions must come before violations; fix, sandbox-
   test, and redeploy (Phase 7). Judgment review is probabilistic: a
   single miss is not a defect, a pattern of misses is a prompt problem.

## Phase 5 — Platform-health check

Run this after any Claude Code upgrade, or as step 4 of troubleshooting.
The policy depends on Claude Code mechanics that change between versions:

1. **Managed source** (managed tier): run `/status` and confirm the
   active managed source is the file-based managed tier — the one the
   toolkit's installer writes. If it reads as remote or server-managed, an
   org admin console has displaced the local file tier, which is now
   inert (distinct from the file-based managed tier throughout this
   skill).
2. **Output-style support**: confirm `outputStyle` is still honored (ask
   Claude whether the named style is active). The switching command has
   changed across versions; the setting is the supported path, but
   re-verify the layer after a major upgrade.
3. **Plugin override**: check enabled plugins for an output style with
   `force-for-plugin: true`, which outranks `outputStyle`.
4. **Hook execution**: confirm the digest fires and the review hook is
   registered (Phase 3). Prompt-type hooks are evaluated by a small
   model; if hook types or fields change in a future version, the
   sandbox probe is the test that catches it. Note that `--safe-mode`
   starts a session with all hooks disabled.

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
  rule, a tightened test, or a banned-phrase entry in the review prompt
  — this is the most valuable maintenance input, because it targets real
  failures rather than hypothetical ones.

Then rework the directive by the style-author method: the
rule/test/example-pair template, the calibration principle (additions
must pay for themselves; trimming counts as much as adding), one change
per verdict. A banned-phrase-only change is a common, low-stakes case —
it updates the Diction section and the review prompt; the redeploy still
re-stages all three files (Phase 7), with the digest re-staged
unchanged. For a broader revision, offer a fresh-eyes pass: spawn the
reviewer lenses from `style-author`'s `resources/review-lenses.md`
against the reworked directive. The compliance-simulation lens needs
`{SCENARIOS}` — reuse the scenarios recorded in `VERIFIED.md`, or ask
the user for 4–5 current real scenarios before spawning it. Present
surviving findings ranked.

Present the reworked directive and iterate — review findings or freeform
edits, one decision per exchange — until the user is pleased with the
result. Do not redeploy until they confirm the document is right.

## Phase 7 — Redeploy and re-verify

After any canonical edit, in order:

1. **Review both condensations** against the reworked directive (Phase
   2, check 2): the digest and the review prompt. Mandatory — they are
   the artifacts that drift silently. Sandbox-test the review prompt if
   it changed (style-author Phase 6 method).
2. **Stage into the style's library folder**
   `~/.claude/edgar-style-policies/<slug>/` (not an ephemeral `mktemp -d`),
   refreshing the persistent bundle in the same act as the redeploy. Write
   the three files the installers require, aborting if any is missing:
   `canonical.md` (no license header), `digest.sh` (from the template,
   leading comment block dropped, `__DIGEST_TEXT__` filled), and
   `review-prompt.txt` (marker first). The installers use whichever JSON
   engine the machine has — python3, osascript (macOS), or node. Only if
   none exists, perform the merge yourself per style-author Phase 6's
   fallback (model-merge, mechanical validation, pre-merged file passed to
   the managed builder's fourth argument or written directly on the user
   tier).
3. **Redeploy to the installed tier** (from Phase 1):
   - *User tier*: run `${CLAUDE_PLUGIN_ROOT}/scripts/install-user.sh
     ~/.claude/edgar-style-policies/<slug> "<Style Name>"` directly.
   - *Managed tier*: run
     `${CLAUDE_PLUGIN_ROOT}/scripts/build-managed-installer.sh
     ~/.claude/edgar-style-policies/<slug> "<Style Name>"` to assemble the self-contained
     `~/install_claude_writing_style.sh`, then have the user run
     `sudo ~/install_claude_writing_style.sh`. It merges into any
     existing managed-settings.json when any JSON engine is available
     — python3, osascript, or node — (backup first), root-owns the
     tree, and deletes itself on success.
4. **Prune backups** if the user wants: each redeploy leaves a
   timestamped `managed-settings.json.bak` (managed) or
   `settings.json.bak` (user); offer to remove old ones, keeping the most
   recent.
5. **Keep the library folder** (it is the permanent bundle, now refreshed);
   have the user fully quit and restart Claude Code, and repeat Phase 3.
   Update the `VERIFIED.md` in that folder with what changed and what was
   verified.

## Phase 8 — Migrate between tiers

To remove the policy entirely, use the `style-uninstall` skill — it owns
the removal procedure (surgical, backup-first, canonical repo untouched).
Migration is different: the user is relocating the policy, not leaving,
so deploy the target tier first, verify it, then remove the old one —
never leave the machine with no policy mid-migration. Also remove any
stale `~/install_claude_writing_style.sh` or
`~/uninstall_claude_writing_style.sh` left by abandoned earlier runs.

- *User → managed*: stage as in Phase 7 step 2 (digest text and review
  prompt from the current deployment or `VERIFIED.md`), run
  `build-managed-installer.sh`, have the user run the sudo installer,
  verify (Phase 3), then remove the user-tier deployment with
  `style-uninstall`'s `uninstall-user.sh`.
- *Managed → user*: stage likewise, run `install-user.sh`, verify, then
  remove the managed deployment with `style-uninstall`'s generated
  `~/uninstall_claude_writing_style.sh` (sudo).

Confirm the tier recorded in Phase 1 (and `VERIFIED.md`) is updated to
the new one for any later maintenance.
