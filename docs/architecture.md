<!--
SPDX-FileCopyrightText: 2026 Gary Frattarola

SPDX-License-Identifier: MIT OR Apache-2.0
-->

# Architecture

How the toolkit turns one writing-style directive into policy that holds
in long sessions, and the exact steps of each process. The README covers
what the toolkit is and how to install it; this document covers how and
why it works.

## The layers and the layer record

A style is deployed as its directive plus the layers its record turns on.
The record is a file named `layers` in the style's library folder, one
`<layer>=on` line per layer; the directive itself is always deployed.

| Layer | Artifact | Seat | What it covers |
|---|---|---|---|
| directive | CLAUDE.md (managed or user tier) | A user message after the system prompt, in the main session and in every subagent except the built-in Explore and Plan agents; re-read at compaction | The rules, in full |
| `digest` | `UserPromptSubmit` command hook | With every prompt | Distance from the point of writing in a long session |
| `output-style` (older) | Output-style file and `outputStyle` | The main session's system prompt only | Superseded; see below |
| `output-style-coding` (older) | `keep-coding-instructions: true` in that file | — | Keeps Claude Code's software engineering instructions beside an output style |
| `stop-review` (older) | `Stop` prompt hook | After every reply | Superseded; see below |
| `commit-emoji-check` (retired in 0.6.0) | `PreToolUse` command hook, matcher Bash | Before a git or gh command ran | Retired; see below |

A folder without a record predates it and deploys the directive and the digest. The two oldest layers are deployed only when a record names them, so a style made before the record existed no longer gets the output style or the review hook on a redeploy; `style-maintain` moves such a style to the current set. A record that names `commit-emoji-check` is read and ignored.

Why three layers are no longer offered. The output style repeats the whole directive in the main session's system prompt; it never reaches subagents, it costs the whole directive again on every request, and a custom output style without `keep-coding-instructions` removes Claude Code's software engineering instructions from the session. The review hook had a small model judge every reply; a `Stop` hook runs after the reply is displayed, so each block showed the user an edited reply beneath the original, and in use (September 2026) it blocked on grounds its own prompt excluded and, once, looped. The judgement it attempted now belongs to the session's model: while writing, and on request through the `style-review` skill. The commit emoji check, a `PreToolUse` hook on Bash, refused a git or gh command whose message contained an emoji. It was retired in 0.6.0 for two reasons found in use. It matched on the command text, not on the message being recorded, so an emoji anywhere in a command that mentioned `git commit` or `gh api`, in a script that edited a document, for example, was refused although nothing was being recorded. And its cheap pre-filter matched the letters git or gh anywhere, so about half of all Bash commands started an interpreter (two, in fact, about 120 ms together) to find nothing. A narrower hook is possible, using the hook handler's `if` filter and a scan of the message alone, but a check that had caught nothing, beside a directive already in context, did not justify the maintenance.

Judgment for meaning, mechanism for form. Whether a phrase is used or quoted, figurative or literal, an emoji expressive or under discussion, is a judgement, and it belongs to the session's model. A script is used only for facts it can establish exactly. The same principle keeps JSON validity a matter for a parser, never for the model that produced the JSON.

## Single source of truth and the condensation

The only editable artifact is the canonical directive in the style's
library folder. Everything deployed is generated from it and never
hand-edited; the managed tier is root-owned to enforce that mechanically.

One artifact is a condensation rather than a copy, and can therefore drift
semantically: the digest. It carries a standing obligation, reviewed
against the directive on every canonical edit, stated in the skills at
generation time and enforced as step one of every redeploy. An older
style's review prompt carries the same obligation while its hook is
deployed, and its literal marker `[writing-style-policy]` as its first
characters is how the installers and uninstallers identify that hook.

## Artifacts by location

```
Toolkit repo (this repo)         skills, templates, scripts, json-tool.sh, tests
Style library (~/.claude/         one folder per style, <slug>/: canonical.md,
  edgar-style-policies)          layers, digest.sh, VERIFIED.md (and, for an
                                 older style, review-prompt.txt) — the persistent
                                 bundle that also serves as the installer's
                                 staging directory
User tier (~/.claude)            writing-style.md, @import line in CLAUDE.md,
                                 hooks/style-digest.sh, settings.json entries;
                                 for an older style, output-styles/<slug>.md
                                 and outputStyle
Managed tier (per OS)            /Library/Application Support/ClaudeCode or
                                 /etc/claude-code: CLAUDE.md, .edgar-style-policy
                                 (the sidecar record), hooks/style-digest.sh,
                                 managed-settings.json entries; for an older
                                 style, .claude/output-styles/<slug>.md; a foreign
                                 CLAUDE.md kept as CLAUDE.md.pre-edgar-style-policy
Home directory (transient)       install_claude_writing_style.sh /
                                 uninstall_claude_writing_style.sh — the
                                 self-contained sudo scripts; self-delete on
                                 success
```

The style name chosen at authoring keys the library: the installers take
it as an argument, and the slug (the folder name, and an output-style file
name for an older style) derives from it. It must stay identical across
authoring, switching, maintenance, and removal; `VERIFIED.md` records it
with the tier, the layers, and the intake scenarios.

## The style library and switching

Authored styles are kept, one folder per style, under
`~/.claude/edgar-style-policies/<slug>/`. The deployable files are exactly
the installer's staging inputs, so a style's library folder is at once its
permanent record and its staging directory — no separate `mktemp` is used
for authoring, maintenance, or switching.

There is no separate registry of stored styles or of which is active. The
set of styles is the set of library folders; the active style is the one
whose `canonical.md` matches the deployed directive (the managed
`CLAUDE.md`, or `~/.claude/writing-style.md`), compared after normalising
trailing newlines. A derived identification cannot fall out of sync with a
stored pointer. (`outputStyle` served this purpose while every style
deployed an output style; it cannot now that the layer is optional.)

Switching is redeploy, not a new mechanism: point the tier's installer at
the target's library folder and run it. Because the installers bring the
tier exactly into line with the target's record, a layer the previous
style had and the target lacks is removed, and every output-style file the
toolkit generated is removed before the target's (if any) is written. At
the user tier a switch is automatic and needs no elevation; at the managed
tier it is one `sudo` per switch, which is why a switching workflow is most
ergonomic at the user tier while the managed tier suits a locked house
style. A switch is not transactional: an interruption can leave the
directive swapped while the settings still carry the previous style's
entries; recovery is re-running the same idempotent installer, and the
post-restart verification catches a partial apply.

## The JSON engine ladder

All JSON work — encoding the settings fragment, bringing existing settings
into line with it, stripping it back out, and validating — runs through
one shared library, `scripts/json-tool.sh`, identically on macOS and Linux:

1. Engine detection, in order: `python3` if it actually executes (an
   execution test, because a Mac without Command Line Tools has a stub
   that resolves on PATH but fails); else `osascript`'s JavaScript
   engine (present on every Mac); else `node`.
2. Four transforms — `fragment`, `merge`, `strip`, `validate` — with
   inputs passed via environment variables and results on stdout. They
   touch no file; the calling shell does all reads, backups, and writes.
   The logic exists exactly twice: once in Python, once in an
   engine-neutral JavaScript core shared by thin osascript and node
   wrappers.
3. Shell helpers used by every script: `read_layers` (the record, or the
   directive and the digest when absent), `toolkit_style_files` and
   `toolkit_style_names` (output-style files the toolkit generated,
   recognised by the description line it writes), and `norm_sha256` (a
   file's SHA-256 with trailing newlines removed). They are written to be
   safe under `set -euo pipefail`.

`merge` brings the settings exactly into line with the fragment: it
removes every toolkit entry (hooks whose command names `style-digest.sh`
or the retired `style-emoji-check.sh`, a Stop prompt hook with the marker,
and an `outputStyle` naming a toolkit style) and then adds the fragment's.
So a redeploy is idempotent, a dropped layer stays dropped, and the hook
entry of the retired emoji check is removed from a machine that has it.

When no engine exists at install time, the guiding model performs the
settings transform itself — it reads the target settings (the managed file
is root-owned but world-readable), brings them into line, and the result
must pass mechanical validation before anything is written; with no
mechanical validator of any kind available, the skills stop rather than
deploy unvalidated content. Two engine-parity limitations are accepted:
the JavaScript rungs lose integer precision above 2^53 and reorder
integer-like object keys (neither occurs in real Claude Code settings),
while output is otherwise byte-identical across engines, including
non-ASCII text. The engines are kept, rather than making the model the
only merger, for three reasons: a parser is an independent check on
model-produced JSON; the scripts must work standalone, with no model in
the loop; and the emitted sudo scripts run where no model can be present.

## Build time versus run time: the sudo boundary

The harness cannot enter passwords, so managed-tier changes split into
two moments. At build time — inside the skill session, where the model
is present — the directive is finished, the digest written, the layer
record set, the fragment encoded and validated, the hashes of every
canonical in the library taken (so the run-time script can tell the
toolkit's own `CLAUDE.md` from a foreign one; an install that predates the
sidecar record is also recognised by the toolkit's other files and
settings entries in the managed directory), and the builder emits a
single self-contained script into the home directory with every payload
inlined in quoted heredocs (collision-guarded sentinels) and the engine
library embedded. At run time — the user typing `sudo` in a terminal —
the emitted script is on its own: it detects its OS, keeps a foreign
`CLAUDE.md` aside, writes the directive and the sidecar record, removes
the layers the record lacks and writes those it has, substitutes the
per-OS hooks path into the fragment, walks the settings ladder
(any-engine live merge, preserving all foreign settings; else the model's
build-time pre-merge; else, installer only, an announced
backup-and-replace), root-owns the tree, prints verification steps, and
deletes itself. The script is deliberately human-readable so it can be
inspected before it is run as root.

## Process walkthroughs

**Author and deploy** (`style-author`): gather exemplar documents and
any existing draft, proactively, both by name; interview only for the
gaps (voice irritations, banned phrases, emoji, claims policy,
formatting, scenarios); synthesize one complete first draft; iterate to
the user's satisfaction through the contradiction pass and a fresh-eyes
review by three context-free subagents; write the digest; choose the
layers with the user and write the record; check for an existing
installation (deploying user-tier under a live managed policy silently
never activates); ask the user's tier; stage into the style's library
folder; run `install-user.sh` directly or emit the sudo installer; verify
in a fully restarted session; record `VERIFIED.md` in the library folder.

**Review a draft** (`style-review`): on the user's request only; find the
active directive and read it in full; review the named draft against every
section, with judgement on use and mention; report each departure with
its location, the rule, and a rewrite; apply only the rewrites the user
accepts.

**Update** (`style-maintain`): audit first — the deployed directive diffed
against the canonical (normalising packaging newlines), the digest
reviewed, ownership and settings checked against the layer record, live
layers confirmed. Rework from evidence: new exemplars and concrete
unwanted behaviors, one change per verdict. Redeploy: re-review the
digest, re-stage into the library folder, rerun the tier's installer,
restart, re-verify. Troubleshooting, the platform-health check, and the
move of an older style to the current layer set live here too.

**Uninstall** (`style-uninstall`): confirm intent; identify the style by
its deployed directive; settings surgery first — remove every toolkit
entry; everything else is preserved, and a failed surgery leaves the
installation intact rather than dangling. Files are removed only after
the surgery succeeds; the managed `CLAUDE.md` only if it is the toolkit's
own, with a kept-aside foreign one restored; the managed directory only
if genuinely empty. The style library is never touched.

**Migrate** (`style-maintain`): deploy the target tier first, verify it,
then remove the old tier with the uninstall machinery — the machine is
never left with no policy mid-migration.

**Switch** (`style-switch`): list the library, marking the active style;
resolve the target to its folder, refusing an incomplete bundle or the
already-active style; detect the installed tier; run that tier's installer
against the target's folder; restart and verify.

**Self-update** (`self-update`): set `autoUpdate` on the marketplace's
`extraKnownMarketplaces` entry in `~/.claude/settings.json` (backup
first), so Claude Code updates the plugin in the background from then on;
refresh the marketplace and update the plugin once now; the user applies
it with `/reload-plugins` or a restart. A plugin update replaces the
toolkit, not a deployed style.

## Invariants

- Deployed copies are never hand-edited; the fix for drift is redeploy.
- The tier matches the style's layer record after every install: toolkit
  entries the record lacks are removed, those it has are present once.
- Settings surgery touches only our entries: hooks whose command names
  `style-digest.sh` or `style-emoji-check.sh` (names reserved to this
  toolkit; the second is retired and is only removed), the review hook by its prompt marker, and an `outputStyle`
  naming a toolkit-generated style. All other hooks and settings survive
  install, reinstall, and uninstall.
- A managed `CLAUDE.md` that is not the toolkit's own is never lost: it is
  kept aside at install and restored at uninstall.
- No mutation before preflight passes, with one scoped exception: the
  user-tier scripts and both uninstallers abort with nothing changed on
  any preflight failure; the emitted installer instead terminates every
  path in a settings write, with announced backup-and-replace as the
  last resort.
- Every settings write is preceded by a timestamped backup.
- Model-produced JSON is never deployed unvalidated.
- Authored styles persist in the library independently of what is
  deployed; uninstall removes the active deployment but never the library.
- Generated user content — the directive, its deployed copies, the digest
  — carries no license; it is the user's own work (see LICENSING.md).

## Testing

`tests/run-tests.sh` is the committed harness. It runs in a scratch directory, touching neither `~/.claude` nor the managed directory, once per available engine (forced with `JSON_TOOL_ENGINE`): the migration from the four older layers to a record, with the hook entry of the retired emoji check removed, merge idempotence, and the strip; and, once, the fallback for a style without a record, a user-tier round trip that must restore the original settings and remove a leftover emoji check, and a managed-tier round trip (the emitted scripts with the managed path and the root-only lines overridden) in which a foreign `CLAUDE.md` and a foreign setting must both survive. Its fixtures are synthetic. Change any script only with the harness passing on every engine.
