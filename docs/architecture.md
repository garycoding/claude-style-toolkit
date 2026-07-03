<!--
SPDX-FileCopyrightText: 2026 Gary Frattarola

SPDX-License-Identifier: MIT OR Apache-2.0
-->

# Architecture

How the toolkit turns one writing-style directive into enforced,
long-context-durable policy, and the exact steps of each process. The
README covers what the toolkit is and how to install it; this document
covers how and why it works.

## The four layers

A directive is deployed to four seats at once because instruction
adherence erodes in long sessions, and each seat fails differently:

| Layer | Artifact | Seat | Failure mode it covers |
|---|---|---|---|
| 1 | CLAUDE.md (managed or user tier) | Primacy; re-read from disk at every compaction | Baseline presence |
| 2 | Output style | End of the system prompt; survives everything | Attention dilution |
| 3 | Digest hook (`UserPromptSubmit`, command type) | Recency; ~70 tokens with every prompt | Distance from the point of generation in very long sessions |
| 4 | Judgment-review hook (`Stop`, prompt type) | End of every turn | Drift past the soft layers |

Layer 4 is judgment, not string matching, by deliberate decision. A
small model evaluates each reply against a review prompt structured as
an ordered decision list: exemptions first (the user explicitly asked
for the element; the element is mentioned, not used), violations after
(only what the directive actually bans — decorative emoji, flattery
openers, the banned-phrase list), default pass last. Ordering matters
because a flat clause pile invites the evaluator to weigh clauses
against each other; the list decides for it. The trade against a
deterministic lint is explicit: judgment can occasionally misjudge,
where a regex never wavers — but a regex cannot tell a quoted example
from a violation, and confidently blocking legitimate prose is the
worse failure for a writing tool. The inverse also holds and shapes the
rest of the design: JSON validity is a question of form, not meaning,
so it is always checked by a parser, never by the model that produced
the JSON. Judgment for meaning, mechanism for form.

## Single source of truth and the two condensations

The only editable artifact is the user's canonical directive (one
Markdown file, durably located, ideally in a repo). Everything deployed
is generated from it and never hand-edited; the managed tier is
root-owned to enforce that mechanically.

Two artifacts are condensations rather than copies, and therefore can
drift semantically: the digest text and the review prompt. Both carry a
standing obligation — reviewed against the directive on every canonical
edit — stated in the skills at generation time and enforced as step one
of every redeploy. The review prompt additionally carries the literal
marker `[writing-style-policy]` as its first characters; that marker is
how the uninstallers identify our hook among any others.

## Artifacts by location

```
Toolkit repo (this repo)         skills, templates, scripts, json-tool.sh
Staging (mktemp, ephemeral)      canonical.md, digest.sh, review-prompt.txt
User tier (~/.claude)            writing-style.md, @import line in CLAUDE.md,
                                 output-styles/<slug>.md, hooks/style-digest.sh,
                                 settings.json entries (outputStyle, digest
                                 command hook, marker prompt hook)
Managed tier (per OS)            /Library/Application Support/ClaudeCode or
                                 /etc/claude-code: CLAUDE.md, hooks/style-digest.sh,
                                 .claude/output-styles/<slug>.md,
                                 managed-settings.json entries (same three)
Home directory (transient)       install_claude_writing_style.sh /
                                 uninstall_claude_writing_style.sh — the
                                 self-contained sudo scripts; self-delete on
                                 success
```

The style name chosen at authoring is load-bearing: the installers take
it as an argument, the slug (output-style filename) derives from it, and
the uninstallers compare it against `outputStyle`. It must stay
identical across install, maintenance, and removal; `VERIFIED.md`,
written next to the canonical, records it along with the tier, the
canonical path, and the intake scenarios.

## The JSON engine ladder

All JSON work — encoding the settings fragment, merging it into
existing settings, stripping it back out, validating — runs through one
shared library, `scripts/json-tool.sh`, identically on macOS and Linux:

1. Engine detection, in order: `python3` if it actually executes (an
   execution test, because a Mac without Command Line Tools has a stub
   that resolves on PATH but fails); else `osascript`'s JavaScript
   engine (present on every Mac); else `node`. In practice at least one
   exists on every supported machine.
2. Four pure transforms — `fragment`, `merge`, `strip`, `validate` —
   with inputs passed via environment variables and results on stdout.
   No engine touches the filesystem; the calling shell does all reads,
   backups, and writes. The logic exists exactly twice: once in Python,
   once in an engine-neutral JavaScript core shared by thin osascript
   and node wrappers.

When no engine exists at all, the guiding model performs the transform
itself — it reads the target settings (the managed file is root-owned
but world-readable), merges or strips, and the result must pass
mechanical validation before anything is written; with no way to
validate, deployment requires the user's explicit consent. The engines
are kept, rather than making the model the only merger, for three
reasons: a parser is an independent check on model-produced JSON (the
model checking its own output is a correlated failure); the scripts
must work standalone, with no model in the loop; and the emitted sudo
scripts run where no model can be present at all.

## Build time versus run time: the sudo boundary

The harness cannot enter passwords, so managed-tier changes split into
two moments. At build time — inside the skill session, where the model
is present — the directive is finished, the condensations are written,
the review prompt is sandbox-tested (`claude -p --settings` against a
throwaway settings file, one clear-violation probe and one mention
probe), the fragment is encoded and validated, and the builder emits a
single self-contained script into the home directory with every payload
inlined in quoted heredocs (collision-guarded sentinels) and the engine
library embedded. At run time — the user typing `sudo` in a terminal —
the emitted script is on its own: it detects its OS, substitutes the
per-OS hooks path into the fragment, walks the settings ladder
(any-engine live merge, preserving all foreign settings and replacing
only our marker-tagged entries; else the model's build-time pre-merge;
else, installer only, an announced backup-and-replace), root-owns the
tree, prints verification steps, and deletes itself. The script is
deliberately human-readable so it can be inspected before it is run as
root.

## Process walkthroughs

**Author and deploy** (`style-author`): gather exemplar documents and
any existing draft, proactively, both by name; interview only for the
gaps (voice irritations, banned phrases, claims policy, formatting,
scenarios); synthesize one complete first draft; iterate to the user's
satisfaction through the contradiction pass (persona anchors, self-
violations, prohibitions that should be labeling regimes, missing
scope/precedence) and a fresh-eyes review by three context-free
subagents; generate digest and review prompt; check for an existing
installation (deploying user-tier under a live managed policy silently
never activates); sandbox-test the review prompt; ask the user's tier;
stage into mktemp; run `install-user.sh` directly or emit the sudo
installer; delete staging; verify in a fully restarted session (a
`/clear` does not reload session-fixed layers); record `VERIFIED.md`.

**Update** (`style-maintain`): audit first — deployed copies diffed
against the canonical (normalizing packaging newlines), both
condensations reviewed, ownership and settings entries checked, live
layers confirmed. Rework from evidence: new exemplars and concrete
unwanted behaviors, one change per verdict, to the user's satisfaction.
Redeploy: re-review both condensations, re-stage all three files, rerun
the tier's installer, restart, re-verify. Troubleshooting and the
platform-health check (managed source via `/status`, output-style
support, plugin overrides, hook execution) live here too.

**Uninstall** (`style-uninstall`): confirm intent; determine the exact
style name from `outputStyle` (the filename is only the slug); settings
surgery first — remove the digest entry by filename, the review hook by
marker, `outputStyle` only if it names this style; everything else is
preserved, and a failed surgery leaves the installation intact rather
than dangling. Files are removed only after the surgery succeeds; the
managed directory is removed only if genuinely empty; if the settings
file held nothing but our policy, the file and this run's backup go
with it. The canonical directive is never touched.

**Migrate** (`style-maintain`): deploy the target tier first, verify it,
then remove the old tier with the uninstall machinery — the machine is
never left with no policy mid-migration.

## Invariants

- Deployed copies are never hand-edited; the fix for drift is redeploy.
- Settings surgery touches only our three entries, matched by exact
  filename and by the prompt marker; foreign hooks and settings survive
  install, reinstall, and uninstall.
- No mutation before preflight passes: engine present (or fallback
  arranged) and existing settings parseable — a failure aborts with
  nothing changed, never a half-install.
- Every settings write is preceded by a timestamped backup.
- Model-produced JSON is never deployed unvalidated.
- Generated user content — the directive, its deployed copies, the
  digest, the review prompt — carries no license; it is the user's own
  work (see LICENSING.md).

## Testing discipline

The scripts are tested by fixture, not inspection: user-tier
install/uninstall round-trips asserting foreign hooks and unrelated
settings survive, run once per engine by forcing `JSON_TOOL_ENGINE`;
emitted sudo scripts checked for valid syntax with the library inlined
and payloads extracted back out and diffed against their sources; the
merge and strip transforms exercised against mixed fixtures (ours-only
collapses to nothing; foreign entries persist). Review prompts are
tested behaviorally before deployment via the sandbox probes. When
changing any script, rerun the matrix on all engines present.
