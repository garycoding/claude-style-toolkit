<!--
SPDX-FileCopyrightText: 2026 Gary Frattarola

SPDX-License-Identifier: MIT OR Apache-2.0
-->

# Writing-style policy on Claude for Mac: a Cowork user's manual

This manual is for someone who uses Claude for Mac and works in the Cowork
tab. It shows how to install the style toolkit, create and deploy an edgar writing
style, revise it, keep several and switch between them, update the plugin, and
remove one. It assumes no terminal and no command-line knowledge; you
do everything by talking to Claude.

## Two ground rules to read first

Everything below rests on two facts about the Cowork tab. Understanding
them will save you every confusion the tool can produce.

First, there are two kinds of slash command, and only one kind works in
Cowork. A skill command, which always begins with `/edgar-style-policy:`
(for example `/edgar-style-policy:style-author`), works when you type it
into the chat. A plugin-management command, `/plugin ...` or
`/reload-plugins`, does not work in Cowork; it belongs to the Claude Code
terminal, and typing it into the app returns "not available in this
environment." Wherever this manual needs one of those, you simply ask
Claude in plain words instead, and Claude runs it for you behind the scenes.

Second, changes load only when a session starts. After anything that
installs, updates, removes, deploys, or switches, you must fully quit
Claude for Mac (Cmd+Q) and open it again. There is no in-app reload in
Cowork. When a step ends with "quit and reopen," that is why; skip it and
nothing you just did will take effect.

One recommendation that follows from the same facts: when Claude offers you
a choice of tier for your style, choose the user tier. It needs no
password and Claude does all of it from Cowork. The managed tier is
sturdier against tampering, but installing or removing it requires you to
run a command with your password in the macOS Terminal, which a Cowork
workflow is meant to avoid. This manual uses the user tier throughout.

## 1. Install the toolkit

The toolkit comes in two parts: a marketplace, which is the catalog Claude
reads from, and the plugin itself, named `edgar-style-policy`. You add both
by asking Claude, once.

1. Open a Cowork chat and ask Claude, plainly: "Please set up a Claude Code
   plugin for me. Add the plugin marketplace from the GitHub repository
   `garycoding/claude-style-toolkit`, then install the `edgar-style-policy`
   plugin from it." Naming it as a Claude Code plugin and a GitHub repository
   is what lets Claude recognize `garycoding/claude-style-toolkit` as an
   address it can add (the command it runs expands that `owner/repo`
   shorthand to the GitHub URL and clones it); Claude then runs the plugin
   commands for you and confirms them. If Claude seems unsure what to do, give
   it these two lines to run: `claude plugin marketplace add
   garycoding/claude-style-toolkit` and `claude plugin install
   edgar-style-policy@claude-style-toolkit`.
2. Fully quit Claude for Mac (Cmd+Q) and open it again.
3. Confirm it worked: in a new Cowork chat, type `/edgar-style-policy:` and
   you should see the toolkit's commands offered (`style-author`,
   `style-switch`, `style-maintain`, `style-uninstall`, `self-update`). If
   you prefer, ask Claude "Is the edgar-style-policy plugin installed, and
   which version?"

Do not type `/plugin ...` into the app to install; it will not work there.
The plain-language request in step 1 is normally all it takes; the two
fallback lines are only for the case where Claude does not recognize the
request.

## 2. Create and deploy your first writing style

An edgar writing style is a set of rules for how Claude writes: its voice, the words it
must avoid, how it formats, how it handles claims. The `style-author` skill
walks you through building one and then deploys it.

1. In a Cowork chat, type `/edgar-style-policy:style-author` (or ask Claude
   to help you create an edgar writing style).
2. Answer Claude's questions. It will ask for the voice you want in a few
   adjectives, what past writing has done wrong, words and phrases to ban,
   formatting preferences, and a name for the style. If you already have
   example documents whose voice you like, offer them; they are the
   strongest material Claude can work from.
3. Claude drafts the style, reviews it with you, and refines it until you
   are satisfied. Take your time here; this is the part that matters.
4. When Claude asks which tier to deploy to, choose the user tier. Claude
   then installs the style with no password required and saves a copy in
   your local library so it can be reused later.
5. Fully quit Claude for Mac (Cmd+Q) and open it again.
6. Confirm it is active: ask Claude "Which edgar writing style is active?" From
   now on Claude follows your edgar writing style when it writes in Cowork.

## 3. Revise an edgar writing style

To change a style you have already made, its voice, a word to ban, a
formatting habit, use the `style-maintain` skill. It edits the style in
place and redeploys it; you do not start over.

1. In a Cowork chat, type `/edgar-style-policy:style-maintain` (or ask
   Claude to update your edgar writing style).
2. Tell Claude what to change. The most useful inputs are concrete: a
   phrase it should stop using, an example document whose voice is right
   or wrong, or a specific thing it wrote that you did not want.
3. Claude revises the style with you, one change at a time, until you are
   satisfied, then redeploys it with no password.
4. Fully quit Claude for Mac (Cmd+Q) and open it again; the revision takes
   effect on the next session.

This changes an existing style. To move between styles you have stored,
see the next section; to update the plugin software itself, see section 5.

## 4. Keep several styles and switch between them

Every style you author is kept in a local library, so you can build more
than one and move between them by name. Nothing you switch away from is
lost.

To create a second style, run `/edgar-style-policy:style-author` again and
give it a different name. Build and deploy it exactly as in section 2; it
joins the first in your library. You now have two.

To switch:

1. In a Cowork chat, type `/edgar-style-policy:style-switch`. Claude lists
   the styles in your library and marks which one is active.
2. Tell Claude which style to switch to, by name.
3. Claude re-deploys the chosen style for you, again with no password.
4. Fully quit Claude for Mac (Cmd+Q) and open it again. The new style takes
   effect on the next session, not the instant you switch.

Switching back is the same procedure; your styles stay in the library
until you deliberately remove them, so you can move between them as often
as you like.

## 5. Update the plugin

When a new version of the toolkit is published, the `self-update` skill
brings you to it. This exists because the ordinary install command does not
upgrade a plugin that is already installed; `self-update` does the whole
thing for you.

1. In a Cowork chat, type `/edgar-style-policy:self-update`.
2. Claude refreshes the catalog, checks your installed version against the
   latest, and, if a newer one exists, updates it for you and tells you the
   new version and what it adds. No password is needed.
3. Fully quit Claude for Mac (Cmd+Q) and open it again to load the new
   version.

If Claude reports you are already on the latest version, there is nothing
to do.

## 6. Remove a style, or remove the plugin

"Uninstall" can mean two different things; here is each.

To remove a writing style but keep the toolkit, use the `style-uninstall`
skill:

1. In a Cowork chat, type `/edgar-style-policy:style-uninstall` and confirm
   when Claude asks. Claude removes the active style's deployed files, with
   no password.
2. Fully quit Claude for Mac (Cmd+Q) and open it again. Claude no longer
   applies the style.

Your library copy of that style is left in place, so you can switch back to
it or redeploy it later; removing a style does not erase it from your
collection.

To remove the toolkit itself, ask Claude in plain words: "Please uninstall
the `edgar-style-policy` plugin." Claude runs the removal for you; then
fully quit and reopen the app. This takes the plugin off your machine but
still leaves your saved styles in the library untouched. If you want those
gone as well, ask Claude to delete the folder
`~/.claude/edgar-style-policies`.

## Quick reference

The one habit that makes all of this work: after you install, deploy,
switch, update, or remove anything, quit Claude for Mac with Cmd+Q and open
it again. Everything else is a matter of typing an `/edgar-style-policy:`
command or asking Claude in plain words, and letting Claude do the work.
You never need to open a terminal, and you should never be asked for a
password; if you are, that is the managed tier, which you can decline in
favor of the user tier this manual uses.
