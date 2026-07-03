---
name: style-switch
description: List the writing-style policies stored in the local library and switch the active one by name. Use when the user wants to switch, change, activate, select, or list their writing styles, or move to a different stored style. Switching re-deploys the chosen style through the existing installers (user tier automatic, managed tier one sudo) and takes effect after a full restart. For creating a new style use style-author; for editing or troubleshooting the active one use style-maintain.
---

# Style-policy switching

You switch the ACTIVE writing-style policy among several the user has
stored in their local library, each authored by `style-author`. Switching
is not on-the-fly: it re-deploys the chosen style through the same
installers `style-author` uses, so a full Claude Code restart is required,
and the managed tier still means one `sudo` run. What this skill adds is
selection by name over a persistent library — it deploys nothing new and
changes none of the deploy mechanics.

## The library

Authored styles live one folder per style under
`~/.claude/edgar-style-policies/<slug>/`, each a full deployable bundle:

- `canonical.md` — the directive, and the single source of truth for that
  style.
- `digest.sh` — the ready-to-install digest hook.
- `review-prompt.txt` — the judgment-review prompt, `[writing-style-policy]`
  marker first.
- `VERIFIED.md` — display name, slug, tier last deployed, digest text,
  review prompt, and test scenarios.

The three deployable files are exactly what the installers expect in a
staging directory, so a style's library folder IS its staging directory,
and a switch simply points the installer at it. The ACTIVE style is not
recorded separately — it is whichever style the live `outputStyle` names.

## Phase 1 — List

Enumerate `~/.claude/edgar-style-policies/*/` (folders that contain a
`canonical.md`). For each, read the display name and the recorded tier
from `VERIFIED.md`. Read the installed tier's live `outputStyle` (from
`~/.claude/settings.json`, or the world-readable `managed-settings.json` on
the managed tier) and mark ACTIVE the style whose `VERIFIED.md` display
name matches it. Present the library plainly: name, slug, and which is
active on which tier.

Flag two conditions rather than hiding them: a folder missing any of the
three deployable files is incomplete and cannot be switched to until it is
re-authored (`style-author`) or repaired (`style-maintain`); two folders
whose names resolve to the same slug are a collision the user must
rename out of, since the slug keys the deployed filenames.

## Phase 2 — Switch

Given a target name or slug:

1. **Resolve** it to one library folder. Refuse, with the reason, if the
   bundle is incomplete, if the name is ambiguous, or if the target is
   already active — a switch to the active style changes nothing and would
   still cost a restart, so it is a no-op worth naming rather than running.
2. **Detect the installed tier** exactly as `style-maintain` Phase 1 does:
   the managed directory present with our files, or user-tier entries in
   `~/.claude`. If NO policy is installed yet, this is a first install and
   not a switch — hand off to `style-author` Phase 6 (ask which tier the
   user wants, then deploy).
3. **Deploy the target from its library folder.** The folder is the
   staging directory; pass it straight to the installer for the detected
   tier:
   - *User tier (no sudo)*: run
     `${CLAUDE_PLUGIN_ROOT}/scripts/install-user.sh
     ~/.claude/edgar-style-policies/<slug> "<Display Name>"`. It overwrites
     the single deployed directive copy, writes the target output style and
     repoints `outputStyle`, overwrites the digest hook, and merges the
     review hook into `~/.claude/settings.json` (backup first; other
     settings preserved). Fully automatic.
   - *Managed tier (one sudo)*: run
     `${CLAUDE_PLUGIN_ROOT}/scripts/build-managed-installer.sh
     ~/.claude/edgar-style-policies/<slug> "<Display Name>"` to assemble
     `~/install_claude_writing_style.sh`, then have the user run, in a
     terminal, `sudo ~/install_claude_writing_style.sh`. It merges
     `managed-settings.json` (backup first; other managed settings
     preserved), root-owns the tree, and deletes itself on success.
4. **Note the harmless leftovers.** The previously active style's
   output-style file (`output-styles/<old-slug>.md`) stays on disk but is
   inert, because `outputStyle` selects by display name; the previous
   style's library folder is untouched, so switching back later is just
   another Phase 2. Offer to prune stale output-style files only if the
   user wants the tidiness; correctness does not require it.
5. **Restart and verify.** Have the user fully quit and restart Claude
   Code — a `/clear` does not reload the output style or managed settings.
   Then run `style-maintain` Phase 3: confirm the target directive and
   output style are active, the digest line arrives, and the marker-tagged
   review hook in the tier's settings now carries the target's prompt. The
   review prompt was sandbox-tested when the style was authored, so no live
   violation test is needed unless it has since changed.

Because a managed switch costs one `sudo` each time, tell a user who
switches often that the user tier is the ergonomic home for a switching
workflow; the managed tier is for a locked house style that rarely
changes.

## Safety

- A switch is not transactional: the installer backs up settings and
  writes each layer, but an interruption mid-run can leave the directive
  swapped while `outputStyle` still names the previous style. Recovery is
  re-running the same idempotent installer; the four layers are consistent
  once it completes, and the post-restart verification catches a partial
  apply.
- Never hand-edit a deployed copy to "switch" — always redeploy from the
  library folder, so all four layers move together.
- Switching removes no style. To take a style off the machine use
  `style-uninstall` (it strips only the active deployment; the library
  folders persist). To edit a stored style use `style-maintain`, which
  refreshes its library bundle when it redeploys.
