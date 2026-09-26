---
name: self-update
description: Turn on automatic updates of the edgar-style-policy plugin from its marketplace, and bring the plugin up to date now, from inside Claude Code. Use when the user wants to update, upgrade, or keep the edgar style toolkit or its skills current. This is about the plugin software, not a writing style; to change or edit a style use style-maintain.
---

# Plugin self-update

You make the `edgar-style-policy` plugin keep itself current. Claude Code
can update a plugin automatically from its marketplace, but for a
third-party marketplace such as this one automatic update is off until it
is turned on. Turning it on is one settings key; this skill sets it, so the
user never edits a settings file, and brings the plugin up to date once now.

## Identifiers

The plugin is `edgar-style-policy`; its marketplace is
`claude-style-toolkit`; qualified, `edgar-style-policy@claude-style-toolkit`.

## Phase 1 — Turn on automatic update

Automatic update follows, first, `autoUpdate` on the marketplace's entry
under `extraKnownMarketplaces` in a settings file. Read
`~/.claude/settings.json`. If `extraKnownMarketplaces.claude-style-toolkit`
exists and `autoUpdate` is already `true`, report that and go to Phase 2.
Otherwise set `extraKnownMarketplaces.claude-style-toolkit.autoUpdate` to
`true`, keeping its `source` and every other key of the file unchanged; if
the marketplace has no entry there yet, add one with the source it was
added from (`{"source": "github", "repo": "garycoding/claude-style-toolkit"}`
for the public repository). Back the file up first
(`settings.json.bak.<timestamp>`), and check that the result parses as JSON
before writing it. The in-session equivalent, for a user who prefers it, is
`/plugin`, the Marketplaces tab, Enable auto-update, which writes the same key.

From then on Claude Code refreshes the marketplace in the background during
each session and installs a newer version on disk; the running session
keeps the version it loaded, and the next session, or `/reload-plugins`,
uses the new one.

## Phase 2 — Update now

Refresh the marketplace (`claude plugin marketplace update
claude-style-toolkit`) and compare the installed version (`claude plugin
list`, the `Version:` line under the plugin) with the marketplace's
(`~/.claude/plugins/marketplaces/claude-style-toolkit/plugins/edgar-style-policy/.claude-plugin/plugin.json`).
If they differ, run `claude plugin update
edgar-style-policy@claude-style-toolkit`. If the refresh fails (offline, or
the remote unreachable), report the error; automatic update is still on and
will catch up later.

## Phase 3 — Apply, and what an update does not do

Tell the user the one step you cannot take: run `/reload-plugins`, or start
a new session, to load the new version. Then say plainly what an update
leaves alone: the plugin's files are replaced, but a deployed style (the
directive, the digest hook, the emoji check, the settings entries) is a
copy made at install time and does not change by itself. When a release
changes what a style deploys, the release notes say so, and a
`style-maintain` redeploy brings the machine into line.
