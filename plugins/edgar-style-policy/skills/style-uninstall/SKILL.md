---
name: style-uninstall
description: Remove an installed writing-style policy for Claude from this machine. Detects the installed tier, removes the deployed directive, output style, digest hook, and judgment-review hook (surgically, leaving any other settings intact), and leaves the canonical directive in the user's repo untouched. For the managed tier it writes a self-contained sudo uninstaller to the home directory. Use when the user wants to uninstall, remove, delete, disable, or tear down their writing style policy or style enforcement setup.
---

# Style-policy uninstall

You remove a deployed style policy from this machine. Removal touches only
the deployed copies — the canonical directive in the user's repository is
never affected, so the policy can be reinstalled at any time. Uninstalling
is not migrating between tiers; migration lives in `style-maintain`.

## Phase 1 — Confirm and locate

Uninstalling is destructive, so confirm intent explicitly before acting.
Tell the user plainly what will and will not happen: the deployed policy
files and settings entries are removed; their canonical directive
(typically a git repo, recorded in `VERIFIED.md`) is untouched; the style
library under `~/.claude/edgar-style-policies/` (every stored bundle,
including this one) is untouched, so the style can be reinstalled or
switched back later with `style-author` or `style-switch`; the change
takes effect after fully quitting and restarting Claude Code, since the
current session was fixed at start.

Then detect the installed tier (as in `style-maintain`, Phase 1):

- **Managed tier**: macOS `/Library/Application Support/ClaudeCode/`,
  Linux `/etc/claude-code/`.
- **User tier**: policy files under `~/.claude/` and `outputStyle` plus
  the digest and marker-tagged review hooks in `~/.claude/settings.json`.

Determine the style name — the exact `outputStyle` value in the tier's
settings file, or failing that the `name:` frontmatter inside the
output-style file. The output-style *filename* is only the slug and is
not sufficient: the settings cleanup compares the display name. Also
check for and remove any stale `~/install_claude_writing_style.sh` or
`~/uninstall_claude_writing_style.sh` left by abandoned earlier runs.

## Phase 2 — Remove

Both removers run the settings surgery FIRST (so a failure leaves the
installation intact rather than dangling), back up the settings file
before touching it, and strip only the policy's own entries: the digest
hook by its command path, the review hook by its
`[writing-style-policy]` prompt marker, and `outputStyle` only if it
names this style. Anything else in the settings is preserved. The surgery runs on
whichever JSON engine the machine has — python3, osascript (macOS), or
node — identically on both OSes. Only if none exists, YOU perform the
strip instead: read the tier's settings file (the managed one is
world-readable), remove exactly our entries yourself, validate the
result mechanically (on macOS, pipe it through the osascript JSON.parse
one-liner in style-author Phase 6), then — user tier — back up and write
it directly, or — managed tier — pass the pre-cleaned file as the third
argument to `build-managed-uninstaller.sh`, whose emitted script applies
it under sudo. Never apply a strip you have not validated.

- **User tier (no sudo)**: run
  `${CLAUDE_PLUGIN_ROOT}/scripts/uninstall-user.sh "<Style Name>"`. It
  cleans `~/.claude/settings.json`, removes the
  `@~/.claude/writing-style.md` import line from `~/.claude/CLAUDE.md`,
  and deletes `~/.claude/writing-style.md`, the output-style file, and
  the digest hook script. Fully automatic.
- **Managed tier (sudo)**: run
  `${CLAUDE_PLUGIN_ROOT}/scripts/build-managed-uninstaller.sh "<Style Name>"`.
  It assembles a self-contained `~/uninstall_claude_writing_style.sh`
  (symmetric with the installer, inspectable before running). Tell the
  user to run, in a terminal, `sudo ~/uninstall_claude_writing_style.sh`.
  It clears the macOS immutable flag first (harmless if unset — the
  toolkit's installers do not apply it, so this only matters if the user
  hardened the files manually with `chflags schg`), performs the settings
  surgery (removing `managed-settings.json` and its own backup only if
  the file held nothing but our policy), removes our files, removes the
  managed directory only if it is now empty — leaving it in place if it
  holds other managed settings — and deletes itself on success. The
  harness cannot enter passwords, which is why this step is the user's
  to run.

## Phase 3 — Verify removal

Have the user fully quit and restart Claude Code, then confirm the
policy is gone: the directive is no longer in context, the output style
is no longer active (ask Claude), and no digest line arrives with a
prompt. If any layer persists, the session may be stale (recheck after
a restart) or, on the managed tier, the sudo uninstaller may not have
been run yet.

Close by reminding the user that the canonical directive in their repo is
intact, so `style-author` (or a reinstall) can restore the policy at any
time — and that if a different output style was selected before this
policy was installed, that selection is not restored automatically: it
survives in the pre-install settings backup, and they can reselect it.
