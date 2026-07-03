<!--
SPDX-FileCopyrightText: 2026 Gary Frattarola

SPDX-License-Identifier: MIT OR Apache-2.0
-->

# claude-style-toolkit

A Claude Code plugin marketplace for writing-style policy. The plugin,
`edgar-style-policy`, bundles three skills:

- **style-author** — guides you through creating a writing-style
  directive Claude will actually follow: intake by interview or by
  mining your existing documents for the voice they embody, drafting on
  the rule/test/example-pair template, a contradiction pass, an
  independent fresh-eyes review, generation of the per-prompt digest and
  the judgment-review prompt, and deployment.
- **style-switch** — keeps a local library of the styles you author and
  switches the active one by name, re-deploying the chosen style through
  the same installers (user tier automatic, managed tier one sudo),
  effective after a restart.
- **style-maintain** — audits an installed policy (drift between
  canonical and deployed copies, condensation staleness, ownership,
  live-layer checks), troubleshoots why a style is not being followed,
  checks for Claude Code platform drift, reworks the directive from new
  example documents and observed unwanted behaviors, redeploys, and
  migrates between tiers.
- **style-uninstall** — removes a deployed policy (surgically, leaving
  any other settings and the canonical directive untouched); writes a
  self-contained sudo uninstaller for the managed tier.

The method and the deployment architecture come from a worked reference
implementation: [claude-style-policy](https://github.com/garycoding/claude-style-policy),
which documents the four-layer design and why it holds up in long
sessions. The full architecture — the layer model, the JSON engine
ladder, the build-time/run-time division at the sudo boundary, the
process walkthroughs, and the invariants — is documented in
[docs/architecture.md](docs/architecture.md).

## Why four layers

Instruction adherence erodes in long sessions as the directive's share of
context shrinks and task-local pressure grows. Each layer covers a
different failure mode:

| Layer | Artifact | Seat | Failure mode it covers |
|---|---|---|---|
| 1 | Managed or user CLAUDE.md | Primacy; re-injected from disk at every compaction | Baseline presence; survives compaction untouched |
| 2 | Output style | End of the system prompt; unconditionally persistent | Attention dilution — the system prompt is the highest-weight placement |
| 3 | `UserPromptSubmit` hook | Recency — a ~70-token digest injected with every prompt | Long gaps between compactions where layers 1–2 sit far from the point of generation |
| 4 | `Stop` judgment-review hook | End of every turn — a small model reviews the reply against the rules | Drift past the soft layers, enforced with intent: it distinguishes *using* a banned element from *mentioning* it |

Layer 4 is deliberately judgment-based, not a string-matching lint. A
regex cannot tell a decorative emoji from a quoted example, or a banned
phrase used as hype from the same phrase under discussion; a reviewing
model can, and its review prompt encodes exemptions before violations in
a fixed order. The trade is explicit: judgment can occasionally misjudge
where a regex never wavers, and it costs one small-model call per turn —
accepted, because the failure mode of determinism (confidently wrong
blocks on legitimate replies) is the worse one for a writing tool.

## Design rationale: one source, several seats

**Single source of truth governs authoring, not deployment.** The only
editable copy of the directive is the user's canonical file. Every
deployed artifact is generated from it and never hand-edited. Two
generated copies cannot drift from each other; SSoT is violated only
when copies can be edited independently.

**Two condensations are hand-maintained and can drift semantically**:
the per-prompt digest and the judgment-review prompt. Both must be
reviewed against the directive on every canonical edit — step 1 of the
redeploy flow in `style-maintain`, and the skills say so at generation
time. Mechanical summarization would trade that visible drift risk for
an unreviewed machine condensation; the review step is the mitigation.

**The two directive seats fail independently.** If output styles churn
upstream, the CLAUDE.md tier stands; if long-context pressure erodes the
user-tier message, the output style stands in the system prompt.
Carrying both costs about 1.2k tokens twice per context.

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

Then invoke the skills as:

```
/edgar-style-policy:style-author
/edgar-style-policy:style-switch
/edgar-style-policy:style-maintain
/edgar-style-policy:style-uninstall
```

## Deployment tiers

The author skill asks which tier you want:

- **User tier (no sudo)** — everything under `~/.claude`; fully
  automatic. Functional but not tamper-resistant: any tool that writes
  to `~/.claude` can alter it.
- **Managed tier (sudo)** — root-owned files at the OS managed path. The
  skill assembles one self-contained installer at
  `~/install_claude_writing_style.sh` (directive, digest, and settings
  fragment embedded, so you can read the sudo script before running it)
  and prints the single command for you to run yourself, since the
  harness cannot enter passwords. The installer merges into any existing
  managed-settings.json using whichever JSON engine the machine has —
  python3, osascript (macOS), or node, identically on both OSes; with no
  engine at all, it writes the merge the guiding model performed and
  validated at build time, and the lossy backup-and-replace path remains
  only as the last resort, announced when taken. It deletes itself on
  success.

Either tier governs local CLI sessions and the desktop app's Code and
Cowork tabs. Plain desktop chat, web, and mobile are not reached by
files on a machine; the chat side takes the directive only via the
account-level "Instructions for Claude" profile field, by hand.

**Second machine / reinstall:** install the plugin, copy your canonical
directive (and `VERIFIED.md`, which records the style name, digest text,
and scenarios), invoke `style-author`, and say the directive is finished
— it skips straight to digest/deploy. Install-time JSON work uses
whichever engine the machine has (python3, osascript, or node); nothing
at runtime depends on any of them.

## Style library and switching

Every style `style-author` creates is stored as a deployable bundle in its
own folder under `~/.claude/edgar-style-policies/<slug>/` (`canonical.md`,
`digest.sh`, `review-prompt.txt`, `VERIFIED.md`). The `style-switch` skill
lists that library and re-activates any stored style by name.

Switching is not on-the-fly. It re-deploys the chosen style through the
same installers, so it takes effect only after a full restart, and the
managed tier still costs one sudo per switch — which makes the user tier
the ergonomic home for a workflow that switches often. Only one style is
active at a time: the one the live `outputStyle` names. The switch repoints
all four layers together; the previous style's output-style file is left on
disk but inert, and its library folder is untouched, so switching back is
another `style-switch`. Invoke it as `/edgar-style-policy:style-switch`.

## Update workflow

1. Edit the canonical directive. Never edit deployed copies — they are
   generated, and the managed tier is root-owned precisely so they
   cannot drift.
2. Review both condensations against the edit: the digest in the staged
   `digest.sh` and the judgment-review prompt. This is the step that
   keeps the two drift-capable artifacts honest.
3. Redeploy via `style-maintain` (it stages, reinstalls the correct
   tier, and re-verifies), then fully quit and restart Claude Code — the
   output style and managed settings are fixed at session start.

## Uninstall

Use the `style-uninstall` skill. User tier: automatic, no sudo. Managed
tier: it writes `~/uninstall_claude_writing_style.sh` for you to run
with sudo; the uninstaller strips only the policy's own files and
settings entries (other managed settings are preserved), removes the
managed directory only if it is left empty, and deletes itself. The
canonical directive in your repo is never touched. If a different
output style was selected before the policy was installed, that
selection is not restored automatically — it survives in the
pre-install settings backup.

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
license — the skill never tags it, and everything it deploys into your
environment (the directive copies, the digest hook, the review prompt)
is header-free private configuration.

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
│   │                            review-prompt template
│   ├── style-switch/SKILL.md
│   ├── style-maintain/SKILL.md
│   └── style-uninstall/SKILL.md
└── scripts/                     json-tool.sh (shared JSON engine ladder),
                                 install-user.sh, uninstall-user.sh (no sudo),
                                 build-managed-installer.sh,
                                 build-managed-uninstaller.sh (emit the
                                 self-contained sudo scripts),
                                 style-digest-template.sh
```
