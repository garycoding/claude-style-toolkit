# claude-style-toolkit

A Claude Code plugin marketplace for writing-style policy. The first
plugin, `style-policy`, bundles two skills:

- **style-author** — guides you through creating a writing-style
  directive Claude will actually follow: intake by interview or by
  mining your existing documents for the voice they embody, drafting on
  the rule/test/example-pair template, a contradiction pass, an
  independent fresh-eyes review, generation of the per-prompt digest,
  and deployment.
- **style-maintain** — audits an installed policy (drift between
  canonical and deployed copies, digest staleness, ownership, live-layer
  checks), guides directive updates, and redeploys.

The method and the deployment architecture come from a worked reference
implementation: [claude-style-policy](https://github.com/garycoding/claude-style-policy),
which documents the four-layer design (managed CLAUDE.md, output style,
per-prompt digest hook, Stop-hook lint) and why it holds up in long
sessions.

## Install

```
/plugin marketplace add garycoding/claude-style-toolkit
/plugin install style-policy@claude-style-toolkit
```

For this private repo, marketplace add works when `gh auth login` (or an
SSH key in ssh-agent) is configured; set `GITHUB_TOKEN` for background
marketplace refresh.

Then invoke the skills as:

```
/style-policy:style-author
/style-policy:style-maintain
```

## Deployment tiers

The author skill deploys to either tier:

- **User tier (default, no sudo)** — everything under `~/.claude`;
  fully automatic. Functional but not tamper-resistant: any tool that
  writes to `~/.claude` can alter it.
- **Managed tier (optional)** — root-owned files at the OS managed
  path; the skill stages everything and prints the one `sudo` command
  for you to run yourself, since the harness cannot enter passwords.

## Layout

```
.claude-plugin/marketplace.json
plugins/style-policy/
├── .claude-plugin/plugin.json
├── skills/
│   ├── style-author/
│   │   ├── SKILL.md
│   │   └── resources/           directive template, review lenses
│   └── style-maintain/SKILL.md
└── scripts/                     install-user.sh, install-managed.sh,
                                 digest and lint templates
```
