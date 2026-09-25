<!--
SPDX-FileCopyrightText: 2026 Gary Frattarola

SPDX-License-Identifier: MIT OR Apache-2.0
-->

# claude-style-toolkit

A Claude Code plugin marketplace for edgar writing-style policy. The plugin,
`edgar-style-policy`, bundles six skills:

- **style-author** — guides you through creating an edgar writing-style
  directive Claude will actually follow: intake by interview or by
  mining your existing documents for the voice they embody, drafting on
  the rule/test/example-pair template, a contradiction pass, an
  independent fresh-eyes review, generation of the per-prompt digest,
  the choice of layers, and deployment.
- **style-review** — on request, reviews a draft that is about to leave
  the machine (a pull-request description, a document, a letter) against
  the active directive, and reports every departure with its location
  and a rewrite.
- **style-switch** — keeps a local library of the styles you author and
  switches the active one by name, re-deploying the chosen style through
  the same installers (user tier automatic, managed tier one sudo),
  effective after a restart.
- **style-maintain** — audits an installed policy (drift between
  canonical and deployed copies, digest staleness, ownership, whether the
  settings match the style's layer record), troubleshoots why a style is
  not being followed, checks for Claude Code platform drift, reworks the
  directive from new example documents and observed unwanted behaviors,
  moves older styles to the current layer set, redeploys, and migrates
  between tiers.
- **style-uninstall** — removes a deployed policy (surgically, leaving
  any other settings and the style library untouched); writes a
  self-contained sudo uninstaller for the managed tier.
- **self-update** — turns on automatic updates of the plugin from its
  marketplace and brings it up to date now, so a new version arrives by
  itself from then on.

The architecture — the layers and the layer record, the JSON engine
ladder, the build-time/run-time division at the sudo boundary, the process
walkthroughs, and the invariants — is documented in
[docs/architecture.md](docs/architecture.md). The toolkit's predecessor,
the private `claude-style-policy` repository of July 2026, is archived.

## The layers

Each style carries a layer record (a `layers` file in its library folder)
that says what is deployed besides the directive itself:

| Layer | Artifact | What it does |
|---|---|---|
| directive (always) | Managed `CLAUDE.md`, or `~/.claude/writing-style.md` imported from `~/.claude/CLAUDE.md` | The full rules in every session's context, the main session and subagents alike (except the built-in Explore and Plan agents); re-read at compaction |
| `digest` | `UserPromptSubmit` command hook | A short restatement of the rules most often broken, injected with every prompt, so they stay close to the point of writing in a long session |
| `commit-emoji-check` | `PreToolUse` command hook on Bash | For a style that bars emoji as a means of expression: refuses once a git commit, tag or merge, or a gh pull-request command, whose message contains an emoji, and asks the model to judge; the unchanged rerun passes. Set `attribution.pr` beside it, since Claude Code's default pull-request attribution line carries an emoji |

Two older layers remain for styles made before the record existed, and are
no longer offered by default. `output-style` repeated the whole directive
in the main session's system prompt; it never reached subagents, cost the
whole directive again on every request, and, without
`keep-coding-instructions`, removed Claude Code's software engineering
instructions from the session. `stop-review` had a small model judge every
reply against the rules; it ran after the reply was displayed, so each
block showed an edited reply beneath the original, and in use it blocked
on grounds its own prompt excluded. `style-maintain` offers to move an
older style to the current set.

## Design rationale

**Judgment for meaning, mechanism for form.** Whether a word is used or
quoted, figurative or literal, expressive or under discussion, is a
judgement. The toolkit leaves that judgement to the session's own model:
while it writes, from the directive in context, and on request with
`style-review` for a draft that will leave the machine. Mechanism is used
only for facts a script can establish exactly, such as whether a commit
message contains an emoji; even there the script only asks, and the model
judges.

**Single source of truth governs authoring, not deployment.** The only
editable copy of the directive is the canonical file in the style's
library folder. Every deployed artifact is generated from it and never
hand-edited.

**One condensation is hand-maintained and can drift semantically**: the
per-prompt digest. It must be reviewed against the directive on every
canonical edit — step 1 of the redeploy flow in `style-maintain`.

**A redeploy never restores a dropped layer.** The installers bring the
tier exactly into line with the style's layer record, removing any
toolkit entry the record lacks.

**Root ownership (managed tier) is the enforcement mechanism** for the
policy files themselves: nothing running as the user — including
Claude's own memory feature — can rewrite them without elevation.

## Install

```
/plugin marketplace add garycoding/claude-style-toolkit
/plugin install edgar-style-policy@claude-style-toolkit
```

The repo is public; no authentication setup is needed. (A local clone
also works: `/plugin marketplace add /path/to/claude-style-toolkit`.)
Then run `/edgar-style-policy:self-update` once to turn on automatic
updates; for a third-party marketplace such as this one they are off by
default.

Invoke the skills as:

```
/edgar-style-policy:style-author
/edgar-style-policy:style-review
/edgar-style-policy:style-switch
/edgar-style-policy:style-maintain
/edgar-style-policy:style-uninstall
/edgar-style-policy:self-update
```

## Deployment tiers

The author skill asks which tier you want:

- **User tier (no sudo)** — everything under `~/.claude`; fully
  automatic. Functional but not tamper-resistant: any tool that writes
  to `~/.claude` can alter it.
- **Managed tier (sudo)** — root-owned files at the OS managed path. The
  skill assembles one self-contained installer at
  `~/install_claude_writing_style.sh` (every file of the style's layers
  embedded, so you can read the sudo script before running it) and prints
  the single command for you to run yourself, since the harness cannot
  enter passwords. The installer keeps an existing managed `CLAUDE.md`
  that is not the toolkit's own as `CLAUDE.md.pre-edgar-style-policy`
  (restored on uninstall) and merges into any existing
  managed-settings.json using whichever JSON engine the machine has —
  python3, osascript (macOS), or node; with no engine at all, it writes
  the merge the guiding model performed and validated at build time, and
  the lossy backup-and-replace path remains only as the last resort,
  announced when taken. It deletes itself on success.

Both tiers govern local CLI sessions and the desktop app's Code tab. The
managed tier also reaches the desktop app's Cowork tab (verified on
macOS). Cowork does not read `~/.claude`, so the user tier is not expected
to reach it; this is being verified on a user-tier machine. Plain desktop
chat, web, and mobile are not reached by files on a machine; the chat side
takes the directive only via the account-level "Instructions for Claude"
profile field, by hand.

**Second machine / reinstall:** install the plugin, copy the style's
library folder (`~/.claude/edgar-style-policies/<slug>/`, which holds the
canonical directive, the layer record and `VERIFIED.md`), invoke
`style-author`, and say the directive is finished — it skips straight to
deployment.

## Style library and switching

Every style `style-author` creates is stored as a deployable bundle in its
own folder under `~/.claude/edgar-style-policies/<slug>/` (`canonical.md`,
`layers`, `digest.sh`, `VERIFIED.md`). The `style-switch` skill lists that
library and re-activates any stored style by name.

Switching is not on-the-fly. It re-deploys the chosen style through the
same installers, so it takes effect only after a full restart, and the
managed tier still costs one sudo per switch — which makes the user tier
the ergonomic home for a workflow that switches often. Only one style is
active at a time: the one whose canonical matches the deployed directive.
The switch brings every layer into line with the target's record, and the
previous style's library folder is untouched, so switching back is another
`style-switch`. Invoke it as `/edgar-style-policy:style-switch`.

## Update workflow

1. Edit the canonical directive in the style's library folder. Never edit
   deployed copies — they are generated, and the managed tier is
   root-owned precisely so they cannot drift.
2. Review the digest against the edit. This is the step that keeps the
   one drift-capable artifact honest.
3. Redeploy via `style-maintain` (it stages, reinstalls the correct
   tier, and re-verifies), then fully quit and restart Claude Code — the
   managed settings and CLAUDE.md are read at session start.

A plugin update replaces the toolkit, not a deployed style. When a release
changes what a style deploys, its notes say so, and a `style-maintain`
redeploy brings the machine into line.

## Uninstall

Use the `style-uninstall` skill. User tier: automatic, no sudo. Managed
tier: it writes `~/uninstall_claude_writing_style.sh` for you to run
with sudo; the uninstaller strips only the policy's own files and
settings entries (other managed settings are preserved), removes the
managed `CLAUDE.md` only when it is the toolkit's own and restores one it
kept aside, removes the managed directory only if it is left empty, and
deletes itself. The style library is never touched. If a different output
style was selected before an older style's installation, that selection
is not restored automatically — it survives in the pre-install settings
backup.

## Tests

`tests/run-tests.sh` runs the scripts in a scratch directory, touching
neither `~/.claude` nor the managed directory, on every JSON engine
available (python3, osascript, node): the migration from the older layers
to a layer record, merge idempotence, the settings strip, the emoji scan
on a table of cases, the commit check's single refusal, and full user-tier
and managed-tier round trips that must restore the original settings and
a foreign managed `CLAUDE.md`.

## License

Licensed under either of

- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or
  <http://www.apache.org/licenses/LICENSE-2.0>), or
- MIT license ([LICENSE-MIT](LICENSE-MIT) or
  <http://opensource.org/licenses/MIT>)

at your option. In SPDX terms: `MIT OR Apache-2.0`. See
[LICENSING.md](LICENSING.md) for the full statement and
[THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md) (there are no
third-party dependencies).

Unless you explicitly state otherwise, any contribution intentionally
submitted for inclusion in this work by you shall be dual-licensed as
above, without any additional terms or conditions.

The license covers the toolkit only. A writing-style directive you
produce with the `style-author` skill is your own work and carries no
license — the skill never tags it, and the copies deployed from it (the
directive, the digest hook) are header-free private configuration. The
toolkit's own scripts that the installers deploy beside them
(`style-emoji-check.sh`, `style-json-tool.sh`) keep their headers.

This repository is [REUSE](https://reuse.software/)-compliant; verify
with `uvx --from "reuse[charset-normalizer]" reuse lint`.

## Layout

```
.claude-plugin/marketplace.json
plugins/edgar-style-policy/
├── .claude-plugin/plugin.json
├── skills/
│   ├── style-author/
│   │   ├── SKILL.md
│   │   └── resources/           directive template, review lenses,
│   │                            review-prompt template (older styles)
│   ├── style-review/SKILL.md
│   ├── style-switch/SKILL.md
│   ├── style-maintain/SKILL.md
│   ├── style-uninstall/SKILL.md
│   └── self-update/SKILL.md
└── scripts/                     json-tool.sh (shared JSON engine ladder and
                                 helpers), install-user.sh, uninstall-user.sh
                                 (no sudo), build-managed-installer.sh,
                                 build-managed-uninstaller.sh (emit the
                                 self-contained sudo scripts),
                                 style-digest-template.sh,
                                 style-emoji-check.sh (the commit check)
tests/                           run-tests.sh and synthetic fixtures
docs/                            architecture.md, in-flight_ideas.md,
                                 the Cowork user guide (MD and HTML)
```
