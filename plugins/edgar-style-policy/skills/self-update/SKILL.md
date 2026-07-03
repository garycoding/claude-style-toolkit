---
name: self-update
description: Update the edgar-style-policy plugin itself to the newest version its marketplace offers, from inside Claude Code. Use when the user wants to update, upgrade, or get the latest version of this plugin, this style toolkit, or its skills. This is about the plugin software, not a writing style; to change or edit a style use style-maintain. It refreshes the marketplace, updates the plugin in place, and leaves the user the single step needed to apply it.
---

# Plugin self-update

You update the `edgar-style-policy` plugin in place to the newest version
its marketplace offers, so the user never has to drop to a shell or recall
the refresh-uninstall-reinstall sequence. This exists because `/plugin
install` does not upgrade an already-installed plugin (it reports "already
installed" and stops), and the interactive `/plugin` manager has no update
affordance.

You run the plugin-management commands on the user's behalf; from the
user's seat the whole operation is one skill invocation. The single thing
you cannot do is reload the session, so applying the update is the user's
closing `/reload-plugins` (or a restart).

## Identifiers

The plugin is `edgar-style-policy`; its marketplace is
`claude-style-toolkit`; qualified, `edgar-style-policy@claude-style-toolkit`.
These are fixed and do not depend on how the user added the marketplace.

## Phase 1 — Check for a newer version

1. Refresh the marketplace metadata (it is a git clone and must pull the
   latest commit before a newer version is visible):
   `claude plugin marketplace update claude-style-toolkit`. If this fails
   (the machine is offline, or the git remote cannot be reached), report
   the error and stop; change nothing.
2. Read the installed version from `claude plugin list` (the `Version:`
   line under `edgar-style-policy@claude-style-toolkit`) and the latest
   available version from the refreshed marketplace clone's manifest,
   `~/.claude/plugins/marketplaces/claude-style-toolkit/plugins/edgar-style-policy/.claude-plugin/plugin.json`
   (the `version` field).
3. If the two are equal, report that the plugin is already on the latest
   version (name it) and stop; there is nothing to update.

## Phase 2 — Update in place

If a newer version is available, run
`claude plugin update edgar-style-policy@claude-style-toolkit` (fall back to
the unqualified `edgar-style-policy` if the marketplace-qualified form is
rejected). Report the before and after versions plainly, and name any
notable new skill the update brings.

You are updating the very plugin this skill belongs to, which is safe: this
skill's instructions are already loaded for the current run, so the swap of
files on disk does not interrupt it. The new files, including any changed
version of this skill, take effect only after the reload below, so do not
expect changed behavior until then.

## Phase 3 — Apply

Tell the user the one step you cannot take for them: run `/reload-plugins`
to activate the new version in this session, or fully quit and restart
Claude Code. Until they do, the previous version stays active. Close by
naming the version they will be on and what it adds.
