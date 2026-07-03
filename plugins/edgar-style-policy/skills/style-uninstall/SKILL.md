---
name: style-uninstall
description: Remove an installed writing-style policy for Claude from this machine. Detects the installed tier, removes the deployed directive, output style, and hooks (surgically, leaving any other settings intact), and leaves the canonical directive in the user's repo untouched. For the managed tier it writes a self-contained sudo uninstaller to the home directory. Use when the user wants to uninstall, remove, delete, disable, or tear down their writing style policy or style enforcement setup.
---

# Style-policy uninstall

You remove a deployed style policy from this machine. Removal touches only
the deployed copies — the canonical directive in the user's repository is
never affected, so the policy can be reinstalled at any time. Uninstalling
is not migrating between tiers; migration lives in `style-maintain`.

## Phase 1 — Confirm and locate

Uninstalling is destructive, so confirm intent explicitly before acting.
Tell the user plainly what will and will not happen: the deployed policy
files are removed; their canonical directive (typically a git repo) is
untouched; the change takes effect in a fresh session, since the current
one was fixed at start.

Then detect the installed tier (as in `style-maintain`, Phase 1):

- **Managed tier**: macOS `/Library/Application Support/ClaudeCode/`,
  Linux `/etc/claude-code/`.
- **User tier**: policy files under `~/.claude/` and `outputStyle` +
  hook entries in `~/.claude/settings.json`.

Determine the style name (from the `outputStyle` value in the settings
file or the output-style filename) — the removers need it to target the
right files and keys.

## Phase 2 — Remove

Both removers back up the settings file first, delete only the policy's
own files, and strip only the policy's own keys from the settings JSON —
any other settings the user has are preserved.

- **User tier (no sudo)**: run
  `${CLAUDE_PLUGIN_ROOT}/scripts/uninstall-user.sh "<Style Name>"`. It
  removes `~/.claude/writing-style.md`, the `@~/.claude/writing-style.md`
  import line from `~/.claude/CLAUDE.md`, the output-style file, and both
  hook scripts, and removes `outputStyle` and the two hook entries from
  `~/.claude/settings.json`. Fully automatic.
- **Managed tier (sudo)**: run
  `${CLAUDE_PLUGIN_ROOT}/scripts/build-managed-uninstaller.sh "<Style Name>"`.
  It assembles a self-contained `~/uninstall_claude_writing_style.sh`
  (symmetric with the installer, inspectable before running). Tell the
  user to run, in a terminal, `sudo ~/uninstall_claude_writing_style.sh`.
  It clears the macOS immutable flag first (harmless if unset — the
  toolkit's installers do not apply it, so this only matters if the user
  hardened the files manually with `chflags schg`), removes our files,
  strips our keys from `managed-settings.json` (removing that file only if
  it held nothing else), removes the managed directory only if it is now
  empty — leaving it in place if it holds other managed settings — and
  deletes itself on success. The harness cannot enter passwords, which is
  why this step is the user's to run.

## Phase 3 — Verify removal

Have the user start a fresh session and confirm the policy is gone: the
directive is no longer in context, the output style is no longer active
(ask Claude), and no digest line arrives with a prompt. If any layer
persists, the session may be stale (recheck after a restart) or, on the
managed tier, the sudo uninstaller may not have been run yet.

Close by reminding the user that the canonical directive in their repo is
intact, so `style-author` (or a reinstall) can restore the policy at any
time.
