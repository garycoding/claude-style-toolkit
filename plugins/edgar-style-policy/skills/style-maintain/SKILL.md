---
name: style-maintain
description: Review, verify, troubleshoot, and update an installed edgar writing-style policy for Claude. Audits deployed files against the canonical directive, checks the live layers (the directive, the digest hook, the commit emoji check, and for older styles the output style and review hook), diagnoses why a style is not being followed, checks for Claude Code platform drift, reworks the directive from new example documents and observed unwanted behaviors, moves older styles to the current layer set, redeploys to the installed tier, and migrates between tiers. Use when the user wants to check, fix, update, revise, re-verify, troubleshoot, or move (migrate) their edgar writing-style policy or style enforcement setup. For removing a policy, use the style-uninstall skill instead.
---

# Style-policy maintenance

You maintain a previously installed style policy (see the companion skill
`style-author` for initial creation). Work one finding or decision per
exchange; never change the user's directive without their verdict. The
canonical directive is the single source of truth — every deployed file is
generated from it, and deployed copies are never hand-edited.

## Phase 1 — Locate the installation

Determine which tier is installed:

- **Managed tier**: macOS `/Library/Application Support/ClaudeCode/`,
  Linux `/etc/claude-code/` — look for `CLAUDE.md`, the sidecar record
  `.edgar-style-policy`, `managed-settings.json` (the toolkit's entries:
  hooks whose command names `style-digest.sh` or `style-emoji-check.sh`,
  and, for an older style, `outputStyle` and a Stop prompt hook whose
  prompt starts with `[writing-style-policy]`), `hooks/`, and
  `.claude/output-styles/*.md`.
- **User tier**: `~/.claude/writing-style.md`, an `@~/.claude/writing-style.md`
  import line in `~/.claude/CLAUDE.md`, `~/.claude/hooks/style-*.sh`,
  `~/.claude/output-styles/*.md`, and the same toolkit entries in
  `~/.claude/settings.json`. `~/.claude/writing-style.md` is a deployed
  copy, not the canonical — never hand-edit it.

Record the tier — later phases (redeploy, migrate) branch on it.

**The style library.** Authored styles are stored as deployable bundles,
one folder per style, under `~/.claude/edgar-style-policies/<slug>/`:
`canonical.md` (the editable source), `layers` (the layer record, one
`<layer>=on` line per layer besides the directive: `digest`,
`commit-emoji-check`, and for older styles `output-style`,
`output-style-coding`, `stop-review`), `digest.sh`, `review-prompt.txt`
(older styles with the review hook only), and `VERIFIED.md`. A folder
without `layers` is an older style that deploys the original four layers
(directive, output style, digest, review hook). The ACTIVE style is the
one whose `canonical.md` matches the deployed directive (the managed
`CLAUDE.md` or `~/.claude/writing-style.md`) after normalising trailing
blank lines; if a canonical was edited since the last deploy, none will
match exactly, and the closest, confirmed with the user, is the active one.
If the user keeps a separate repository master, `VERIFIED.md` records its
path and the two must be kept in step. If no library folder exists for the
installed style, offer to seed one from the deployed directive, which is
identical to the canonical body up to a trailing newline. Switching the
active style among stored ones belongs to `style-switch`.

## Phase 2 — Integrity audit

Report each check as pass/fail with the evidence:

1. **Drift**: diff the deployed directive against the canonical: on the
   managed tier `<managed dir>/CLAUDE.md`, on the user tier
   `~/.claude/writing-style.md` (the deployed `~/.claude/CLAUDE.md` holds
   only the `@import` line). If the output-style layer is on, also diff
   the output-style body, stripping its YAML frontmatter first. Compare
   after normalising boundary blank lines: a single leading or trailing
   blank-line difference is deploy packaging, not drift. Any remaining
   difference means a deploy was missed after an edit — the fix is
   redeploy, never hand-editing deployed copies.
2. **Condensation review**: the digest is a hand-maintained condensation
   of the directive and drifts silently. Read the digest text in the
   deployed `style-digest.sh` against the current directive: every rule it
   states must still be in the directive, and no high-frequency rule
   added since should be missing. For an older style with the review
   hook, review its prompt the same way.
3. **Ownership** (managed tier): the managed directory and every file in
   it should be root-owned. A user-owned parent directory lets files be
   deleted without elevation.
4. **Settings match the layer record**: exactly the toolkit entries the
   record calls for are present, each once; the hook commands point at
   existing executable files; no toolkit entry the record lacks remains
   (a leftover `outputStyle`, review hook, or output-style file after the
   record dropped that layer means the last deploy predates the record —
   redeploy).
5. **Library bundle**: the active style's folder holds the files its
   layers need, and its `canonical.md` and `digest.sh` match the live
   deployment (after normalising boundary blank lines). That folder is
   what `style-switch` redeploys, so a divergence means switching away and
   back would silently change the policy; the fix is to refresh the bundle
   (Phase 7), never to hand-edit deployed copies.

## Phase 3 — Live verification

In the current session (or instruct the user to run these in a fresh
one): confirm the directive is present in context; confirm the digest
line arrived with the user's prompt, if that layer is on; confirm the
commit emoji check is registered (Phase 2, check 4), if that layer is on
— its behaviour is covered by the toolkit's `tests/run-tests.sh`, which
the user can run from a clone. If the user works in a desktop app, have
them repeat the context check once in a Code tab session, and in a Cowork
session at the managed tier (Cowork does not read `~/.claude`, so the user
tier does not reach it).

## Phase 4 — Troubleshooting: the style is not being followed

The most common reason to open this skill. Work the diagnostic tree in
order and stop at the first cause found:

1. **Stale session.** Managed settings and CLAUDE.md are read at session
   start. If the policy was just installed or changed, the current
   session predates it — have the user fully quit and restart Claude
   Code (`/clear` alone does not reload them) and recheck.
2. **Not actually active.** Run Phases 2–3. If the directive is not in
   context, the install is broken or incomplete — go to Phase 7 and
   redeploy.
3. **Wrong session type.** Cloud and web sessions are not reached by
   endpoint files — only server-managed settings deliver policy there.
   Cowork reads the managed tier but not `~/.claude`. Confirm the user is
   in a session the installed tier reaches.
4. **Platform displacement.** Run Phase 5 — server-managed settings from an
   org admin console silently displace the file-based managed tier, and a
   plugin output style with `force-for-plugin: true` overrides the
   session's output style.
5. **Condensation gap.** If the tone drifts only in long sessions, the
   digest may be stale or too thin for the rules being broken (Phase 2,
   check 2): extend it with the rules actually broken.
6. **Outward-facing text.** For text that leaves the machine, offer the
   `style-review` skill on the draft before it is sent; it judges the
   whole draft against the whole directive and reports each departure
   with a rewrite. For an older style that still carries the review hook
   and over-blocks, that is a reason to move it to the current layer set
   (Phase 7a).

## Phase 5 — Platform-health check

Run this after any Claude Code upgrade, or as step 4 of troubleshooting.
The policy depends on Claude Code mechanics that change between versions:

1. **Managed source** (managed tier): run `/status` and confirm the
   active managed source is the file-based managed tier — the one the
   toolkit's installer writes. If it reads as remote or server-managed, an
   org admin console has displaced the local file tier, which is now
   inert.
2. **Plugin override**: check enabled plugins for an output style with
   `force-for-plugin: true`, which outranks any `outputStyle`.
3. **Hook execution**: confirm the digest fires and the emoji check is
   registered (Phase 3). If hook fields or exit-code semantics change in
   a future version, run the toolkit's tests and a live commit with an
   emoji in a scratch repository. Note that `--safe-mode` starts a session
   with all hooks disabled.
4. **Older layers** (older styles only): confirm `outputStyle` is still
   honoured and the review hook is registered; better, move the style to
   the current layer set (Phase 7a).

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
  rule, a tightened test, or a banned-phrase entry — this is the most
  valuable maintenance input, because it targets real failures rather
  than hypothetical ones.

Then rework the directive by the style-author method: the
rule/test/example-pair template, the calibration principle (additions
must pay for themselves; trimming counts as much as adding), one change
per verdict. For a broader revision, offer a fresh-eyes pass: spawn the
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

1. **Review the digest** against the reworked directive (Phase 2, check 2).
   Mandatory — it is the artifact that drifts silently.
2. **Stage into the style's library folder**
   `~/.claude/edgar-style-policies/<slug>/` (not an ephemeral `mktemp -d`),
   refreshing the persistent bundle in the same act as the redeploy:
   `canonical.md` (no license header), `layers`, and `digest.sh` when the
   digest is on (from the template, leading comment block dropped,
   `__DIGEST_TEXT__` filled). The installers use whichever JSON engine the
   machine has — python3, osascript (macOS), or node. Only if none exists,
   perform the merge yourself per style-author Phase 6's fallback
   (model-merge, mechanical validation, pre-merged file passed to the
   managed builder's fourth argument or written directly on the user
   tier).
3. **Redeploy to the installed tier** (from Phase 1):
   - *User tier*: run `${CLAUDE_PLUGIN_ROOT}/scripts/install-user.sh
     ~/.claude/edgar-style-policies/<slug> "<Style Name>"` directly.
   - *Managed tier*: run
     `${CLAUDE_PLUGIN_ROOT}/scripts/build-managed-installer.sh
     ~/.claude/edgar-style-policies/<slug> "<Style Name>"` to assemble the
     self-contained `~/install_claude_writing_style.sh`, then have the user
     run `sudo ~/install_claude_writing_style.sh`. It brings the managed
     tier into line with the layer record (backup first; other managed
     settings preserved), root-owns the tree, and deletes itself on success.
   Either installer removes toolkit entries and files the record lacks, so
   a redeploy never restores a dropped layer.
4. **Prune backups** if the user wants: each redeploy leaves a
   timestamped `managed-settings.json.bak` (managed) or
   `settings.json.bak` (user); offer to remove old ones, keeping the most
   recent.
5. **Keep the library folder** (it is the permanent bundle, now refreshed);
   have the user fully quit and restart Claude Code, and repeat Phase 3.
   Update the `VERIFIED.md` in that folder with what changed and what was
   verified.

## Phase 7a — Move an older style to the current layer set

A style whose folder has no `layers` file deploys the original four layers,
two of which are no longer recommended: the output style repeats the whole
directive in the main session's system prompt (never in subagents), and,
unless `keep-coding-instructions` is set, removes Claude Code's software
engineering instructions; the review hook judges every reply after it is
displayed, so each block shows an edited reply beneath the original.
Offer the move, explain those two reasons once, and let the user choose.
If they agree, write `layers` with `digest=on` (and `commit-emoji-check=on`
if the directive bars emoji as a means of expression), then redeploy
(Phase 7). The installers remove the output-style files, `outputStyle` and
the review hook as part of that redeploy. The `review-prompt.txt` may stay
in the folder; nothing deploys it once `stop-review` is off.

## Phase 8 — Migrate between tiers

To remove the policy entirely, use the `style-uninstall` skill — it owns
the removal procedure (surgical, backup-first, library untouched).
Migration is different: the user is relocating the policy, not leaving,
so deploy the target tier first, verify it, then remove the old one —
never leave the machine with no policy mid-migration. Also remove any
stale `~/install_claude_writing_style.sh` or
`~/uninstall_claude_writing_style.sh` left by abandoned earlier runs.

- *User → managed*: stage as in Phase 7 step 2, run
  `build-managed-installer.sh`, have the user run the sudo installer,
  verify (Phase 3), then remove the user-tier deployment with
  `style-uninstall`'s `uninstall-user.sh`.
- *Managed → user*: stage likewise, run `install-user.sh`, verify, then
  remove the managed deployment with `style-uninstall`'s generated
  `~/uninstall_claude_writing_style.sh` (sudo).

Confirm the tier recorded in `VERIFIED.md` is updated to the new one for
any later maintenance.
