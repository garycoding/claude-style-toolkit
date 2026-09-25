---
name: style-author
description: Guide the user through authoring a personal or company edgar writing-style directive for Claude — starting from an interview or from the user's exemplar documents — then review it for contradictions, run a fresh-eyes multi-agent review, generate the per-prompt digest, choose the layers, and deploy the policy to Claude Code (user-tier, no sudo, or managed tier). Use when the user wants to create, bootstrap, or install an edgar writing style (a writing-style policy or style guide) for AI output.
---

# Style-directive authoring and deployment

You are guiding the user through producing a writing-style directive that
Claude will actually follow, then deploying it as layered policy. Work one
decision per exchange: present a finding or a draft, get the user's
verdict, apply it, move on. Never apply unapproved changes to their
directive.

## Standing principles

- **Calibration.** Enough detail to achieve the effect — too little and
  models stray, too much wastes tokens and dilutes retrieval. Every
  proposed addition must pay for itself; trimming is as valuable as
  adding.
- **The template.** Every rule should be: RULE (the directive), TEST (an
  operational criterion a model can apply), ONE EXAMPLE PAIR (one
  positive, one negative, anchoring the boundary). A rule without a test
  lets models stray; a test without an example leaves the boundary
  abstract; more than one or two examples per rule dilutes retrieval.
  Self-testing rules ("do not use emojis") need no example.
- **Single source of truth.** One canonical Markdown file. Everything
  else — deployed copies, the digest, any pasted variants — is generated
  from it or reviewed against it.
- **Judgment for meaning, mechanism for form.** Whether a phrase is used
  or quoted, figurative or literal, expressive or under discussion, is a
  judgement, and it is made by the session's own model: while writing,
  from the directive in context, and on request with the `style-review`
  skill for a draft that will leave the machine. Mechanism is kept for
  facts a script can establish exactly, such as whether a commit message
  contains an emoji; even there, the script only asks, and the model
  judges. The toolkit installs no after-the-fact review of every reply: a
  `Stop` hook runs once the reply is already on screen, so each block
  shows the user an edited reply beneath the original.
- **The user owns the content.** You own the structure and the process.
  When their preference conflicts with your advice, say so once, then
  follow their verdict.
- **The style library.** Every authored style is stored as a persistent
  deployable bundle in its own folder under
  `~/.claude/edgar-style-policies/<slug>/` (`canonical.md`, `digest.sh`,
  `layers`, `VERIFIED.md`), so the user can keep several named
  styles and switch between them with the `style-switch` skill. Naming is
  therefore load-bearing: the style name keys the library and must stay
  identical across author, switch, maintain, and uninstall.

## Phase 0 — Gather source material

Before anything else, proactively prompt the user for both of the
following. Do not wait for them to volunteer these, and do not treat them
as an either/or — ask for both by name, because a user often has material
they would not think to mention:

- **Exemplar documents**: 3–10 finished pieces whose voice they consider
  right — their best press releases, letters, reports, posts. Read them
  and mine the implicit style: register, diction level, sentence
  complexity, formatting habits, how claims are hedged or asserted, what
  never appears. Take example pairs from their actual sentences wherever
  possible — a positive example in the author's own words anchors better
  than an invented one.
- **An existing draft**: any style guide, rough directive, or partial
  notes they already have. If they bring one, you are refining, not
  starting from scratch — preserve their wording where it is precise and
  upgrade it to the rule/test/example-pair template where it is vague.

A user may bring both, one, or neither. Read everything they provide in
full before drafting. Phase 1 then fills the gaps the material leaves
open — and when the user brings neither exemplars nor a draft, Phase 1
is a full interview that gathers everything the first draft needs.

One special case skips ahead: if the user arrives with a FINISHED
directive (e.g., installing on a second machine, or re-deploying after
an uninstall), confirm they want no review, settle the canonical path
and style name first (the Phase 2 "settle" step — on a second machine
the style name must match the one already in use elsewhere), then go
directly to Phase 5.

## Phase 1 — Intake interview

Collect, in the user's own words — but skip anything the exemplars or the
existing draft already establish, and confirm rather than re-ask it:

- Voice: five or six adjectives, and — more useful — what AI output has
  done wrong for them before (specific irritations become rules).
- Audiences and deliverable types (each may need a scope clause).
- Banned words and phrases — get the literal list; it feeds the Diction
  section and the digest (Phase 5). For a PR or marketing user this list
  is often the highest-value artifact.
- Emoji: whether they may be used at all. If the user bars them as a
  means of expression, the directive says so, and the commit emoji check
  (Phase 6) enforces it for commit messages and pull-request texts.
- Claims policy: what may be asserted, what needs evidence, how
  uncertainty is expressed. (For commercial writing: what counts as an
  inflated claim.)
- Formatting: lists vs prose, emphasis, emojis, headings, length norms.
- Correspondence: whether greetings/thanks/sign-offs are structure to
  keep (they usually are).
- Whether output in other languages should follow the same standards.
- 4–5 real, recent writing scenarios (deliverable, audience, one-line
  brief). These become `{SCENARIOS}` for the Phase 4 compliance
  simulation and are recorded in VERIFIED.md for later maintenance.

## Phase 2 — First draft

Synthesize the exemplars, any existing draft, and the interview into a
complete first draft of the user's `AI_comm_and_writing_style.md`, using
`resources/directive-template.md` as the skeleton. Keep the user's
wording where it is precise; upgrade it to the rule/test/example-pair
template where it is vague. Include the standard closing sections from
the template (Scope and precedence, Formatting, Compact Instructions) —
they exist because their absence is a known failure mode, but adapt their
content to the user.

Settle three things now and reuse them verbatim in every later phase:
the canonical path where the directive lives — this is `{DOC_PATH}` for
the review lenses, and it must be somewhere durable the user can find
again (their repo if they have one; otherwise the style's own library
folder is the default home,
`~/.claude/edgar-style-policies/<slug>/canonical.md`, created when you
first write the draft there); a short style
name agreed with the user (for example "PR Voice") — the installers take
it as a positional argument and derive the output-style filename from
it, so it must stay identical across install, maintain, and uninstall;
and, before deploying, whether a policy is already installed (Phase 6
checks this).

Present the complete first draft to the user. This begins the
back-and-forth: from here you refine the document with them — the
contradiction pass and fresh-eyes review below, plus any change they
ask for directly — one decision per exchange, and you keep iterating
until they are pleased with the result. Do not proceed to the digest
and deployment until the user says the document is right.

## Phase 3 — Contradiction pass

Check the draft against the four failure classes that recur in style
directives, and fix each with the user's verdict, one at a time:

1. **Persona anchors that ban their own markers** ("write like an Ivy
   League PhD... no academic posturing"). Replace the archetype with the
   behaviors it was a proxy for.
2. **Rules the document itself violates** (an idiom ban stated in an
   idiom). The document must pass its own tests.
3. **Prohibitions that should be labeling regimes** ("never guess" vs
   "never present a guess as fact; label it"). Absolute bans on useful
   behavior produce erratic compliance; labeling preserves the intent.
4. **Missing scope and precedence** — no carve-outs for contexts where
   external conventions win, no clause for explicit override requests,
   no statement of which rules never yield.

## Phase 4 — Fresh-eyes review

Spawn three independent subagents, none with your conversation context,
using the prompts in `resources/review-lenses.md`: a template auditor
(rule/test/example coverage), a cold reader (ambiguity, conflicts,
self-violations), and a compliance simulator (apply the directive to the
scenarios collected in Phase 1 — substitute them for `{SCENARIOS}`, and
the Phase 2 canonical path for `{DOC_PATH}`). Discard findings that
would bloat the document; present survivors ranked, and apply only what
the user approves.

The back-and-forth ends when the user is satisfied, not when this phase
completes. After substantial changes, offer another fresh-eyes pass, and
keep refining — review findings or freeform edits — until the user
confirms the document is right. Only then continue to Phase 5.

## Phase 5 — Digest

The digest is generated from the finished directive and injected with
every prompt, which keeps the rules near the point of writing in a long
session. It is a hand-maintained condensation, so it must be reviewed
against the directive on every future edit — tell the user this plainly.

Write it as declarative statements only (text framed as system-voice
commands can trip prompt-injection defenses). Name the rules most often
broken (voice, the formatting bans, the banned words, claims discipline);
a digest of about 60 to 80 tokens is the usual size, and a longer one is
acceptable when the user wants more of the directive restated each turn,
since it is then the only per-turn reminder. End by noting that the full
directive is in the managed or user CLAUDE.md.

## Phase 6 — Deploy

**Check for an existing installation first.** Look for a managed-tier
policy (the managed directory exists with a CLAUDE.md) and for user-tier
entries (`~/.claude/writing-style.md`, or our hooks in
`~/.claude/settings.json`). If one exists, reuse its style name and tier
(this is a redeploy), or route through `style-uninstall` first — deploying
a user-tier policy under an existing managed one silently never
activates, because managed settings win.

**Licensing of what you generate.** The directive is the user's own work
and belongs solely to them: never write a license header, SPDX tag, or
copyright line into `canonical.md` or into anything deployed from it.
When you copy the digest template into staging, drop its entire leading
comment block (the SPDX lines and the TEMPLATE note), keeping only the
shebang and the operational note. The toolkit's own files that the
installers deploy beside it (`style-emoji-check.sh`, `style-json-tool.sh`)
are toolkit code and keep their headers.

**Choose the layers, with the user.** The directive always deploys, as the
managed `CLAUDE.md` or as `~/.claude/writing-style.md` imported from
`~/.claude/CLAUDE.md`; it reaches the main session and every subagent
except the built-in Explore and Plan agents. Beside it, ask about:

- `digest` (recommended): the per-prompt reminder of Phase 5.
- `commit-emoji-check`: offer it when the directive bars emoji as a means
  of expression. A `PreToolUse` hook refuses once a git commit, tag or
  merge, or a gh pull-request command, whose message contains an emoji,
  and asks the model to judge: replace an emoji that expresses or
  decorates; re-run unchanged when the emoji is itself the subject under
  discussion, and the rerun passes. It runs before anything is recorded,
  so the user never sees an edited message. Wherever it is installed, also
  set `attribution.pr` in `~/.claude/settings.json` (back the file up
  first) to `Generated with [Claude Code](https://claude.com/claude-code)`:
  Claude Code's default pull-request attribution line carries an emoji,
  and without the setting every pull request Claude opens is refused once.

Two older layers exist for styles made before the layer record; new styles
do not use them (the review hook would need a `review-prompt.txt`, which
only an older style's folder holds), and the user should hear why if they
ask: `output-style` repeats the directive in
the system prompt of the main session only (subagents never receive
it), at the cost of the whole directive again on every request, and a
custom output style drops Claude Code's software engineering instructions
unless `output-style-coding` is also on; `stop-review` is a small-model
review of every reply that runs after the reply is displayed, so each
block shows an edited reply beneath the original, and in use it has
blocked on grounds its own prompt excluded. Offer the on-request
`style-review` skill instead.

Write the choice to the bundle's layer record, `layers`, one line per
layer that is on (for example `digest=on` and `commit-emoji-check=on`). A
bundle without a `layers` file is treated as an older style and deploys
the original four layers, so always write one for a new style.

**Preflight.** The installers run their JSON work on whichever engine
the machine has, identically on macOS and Linux: `python3` if it
executes (test with `python3 -c 'import json'`, not a PATH check — a
stock Mac without Command Line Tools has a stub that resolves but
fails), else `osascript` (present on every Mac), else `node`. In
practice at least one exists on every supported machine. The commit
emoji check uses the same ladder at run time, only for git and gh
commands, and lets the command through when no engine is found. Only if
NONE exists at install time do you perform the merge yourself:

- *User tier*: read `~/.claude/settings.json`, bring it into line with
  the layer record yourself (remove any hook whose command names
  `style-digest.sh` or `style-emoji-check.sh`, any marker-tagged Stop
  prompt hook, and an `outputStyle` naming a toolkit style; then add the
  entries of the layers that are on), validate the result mechanically
  before writing — on macOS pipe it through
  `osascript -l JavaScript -e 'ObjC.import("Foundation"); const
  d=$.NSFileHandle.fileHandleWithStandardInput.readDataToEndOfFile;
  JSON.parse(ObjC.unwrap($.NSString.alloc.initWithDataEncoding(d,
  $.NSUTF8StringEncoding))); "ok"'` — back up the original, write the
  merged file, and place the remaining files by hand, mirroring what
  `install-user.sh` does.
- *Managed tier*: the managed settings file is root-owned but
  world-readable, so read it, merge the fragment yourself (keep the
  `__CS_HOOKS_DIR__` placeholder in our entries — the installer
  substitutes it per-OS), validate as above, and pass the merged file as
  the fourth argument to `build-managed-installer.sh`. The builder itself
  needs an engine to run, so on a machine with none at all the managed
  path is unavailable — route to the user tier or have python3 installed
  first.

Model-merged JSON must always pass mechanical validation before it is
written or embedded — on macOS the osascript one-liner above; on Linux
without python3, `jq -e . <file>` if jq exists. If no mechanical
validator of any kind is available, stop and have the user install
python3 rather than deploy unvalidated content.

**Stage into the style library.** Each authored style is kept as a
persistent bundle in its library folder,
`~/.claude/edgar-style-policies/<slug>/` (the `<slug>` is the style name
lowercased with non-alphanumerics turned to hyphens, matching what the
installers derive). Ensure that folder holds `canonical.md` (the
directive, no license header), `layers`, and `digest.sh` when the digest
is on (from `style-digest-template.sh`, comment block dropped,
`__DIGEST_TEXT__` replaced with the Phase 5 digest). This folder is at
once the deployable staging directory and the permanent library entry
that `style-switch` later re-activates by name, so use it rather than an
ephemeral `mktemp -d`, and do not delete it after deploying.

**Ask the user which tier they want — do not choose for them.** Present
the trade-off in one exchange: the user tier is fully automatic and
needs no password, but nothing in `~/.claude` is tamper-resistant, so
any tool that writes there (including Claude's own memory feature) could
alter the policy; the managed tier is root-owned and cannot be
overridden or edited locally without elevation, but it requires the user
to run one `sudo` command in a terminal, since the harness cannot enter
passwords. Recommend the user tier for a personal machine where the
concern is drift rather than tampering, and the managed tier for anyone
who wants the policy frozen. Deploy only the tier they choose.

- **User tier**: run `${CLAUDE_PLUGIN_ROOT}/scripts/install-user.sh
  ~/.claude/edgar-style-policies/<slug> "<Style Name>"`. It imports the
  directive into `~/.claude/CLAUDE.md` (append, never overwrite) and
  brings the hooks and `~/.claude/settings.json` exactly into line with
  the layer record (backup first; other settings preserved). Fully
  automatic.
- **Managed tier**: run
  `${CLAUDE_PLUGIN_ROOT}/scripts/build-managed-installer.sh
  ~/.claude/edgar-style-policies/<slug> "<Style Name>"`. It assembles ONE
  self-contained installer at `~/install_claude_writing_style.sh` with
  every file of the chosen layers embedded inline (human-readable,
  inspectable before running). Tell the user to run, in a terminal,
  `sudo ~/install_claude_writing_style.sh`. It keeps an existing managed
  `CLAUDE.md` that is not the toolkit's own as
  `CLAUDE.md.pre-edgar-style-policy` (restored on uninstall), brings
  `managed-settings.json` into line with the layer record (other managed
  settings preserved), root-owns the tree, and deletes itself on success.

After deploying, keep the library folder and remove only any scratch
files you created elsewhere. Explain the deployed layers once, briefly,
and name the covered surfaces: the managed tier reaches local CLI
sessions and the desktop app's Code and Cowork tabs; the user tier
reaches local CLI and Code-tab sessions but not Cowork, which does not
read `~/.claude`; plain desktop chat, web, and mobile are not reached by
files on this machine.

## Phase 7 — Verify

Have the user fully quit and restart Claude Code — managed settings and
CLAUDE.md are read at session start, and a `/clear` does not reload them.
Then, in the fresh session: ask Claude whether the directive is in its
context; confirm the digest line arrives with a prompt, if that layer is
on; if the commit emoji check is on, confirm the hook is registered in
the tier's settings file (its behaviour is covered by the toolkit's
tests, `tests/run-tests.sh`). If the user works in a desktop app, have
them repeat the context check once in a Code tab session, and in a Cowork
session at the managed tier.

Record in a `VERIFIED.md` in the style's library folder
`~/.claude/edgar-style-policies/<slug>/`: what passed, the style name,
the tier, the layers, the canonical path, the digest text, and the Phase 1
scenarios (style-maintain and style-switch reuse all of these for
redeploys, switches, migrations, and second machines).
