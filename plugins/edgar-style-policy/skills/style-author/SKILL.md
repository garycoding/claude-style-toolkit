---
name: style-author
description: Guide the user through authoring a personal or company writing-style directive for Claude — starting from an interview or from the user's exemplar documents — then review it for contradictions, run a fresh-eyes multi-agent review, generate the per-prompt digest and the judgment-review prompt, and deploy the policy to Claude Code (user-tier, no sudo, or managed tier). Use when the user wants to create, bootstrap, or install a writing style policy or style guide for AI output.
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
  else — deployed copies, the digest, the review prompt, any pasted
  variants — is generated from it or reviewed against it.
- **Judgment over string-matching.** Enforcement in this toolkit is
  always judgment review: a small model evaluates each reply against the
  rules with intent (a quoted example of a banned phrase is not a
  violation; a decorative emoji is). There is no deterministic lint.
- **The user owns the content.** You own the structure and the process.
  When their preference conflicts with your advice, say so once, then
  follow their verdict.

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
an uninstall), confirm they want no review, then go directly to Phase 5.

## Phase 1 — Intake interview

Collect, in the user's own words — but skip anything the exemplars or the
existing draft already establish, and confirm rather than re-ask it:

- Voice: five or six adjectives, and — more useful — what AI output has
  done wrong for them before (specific irritations become rules).
- Audiences and deliverable types (each may need a scope clause).
- Banned words and phrases — get the literal list; it feeds both the
  Diction section and the judgment-review prompt (Phase 5). For a PR or
  marketing user this list is often the highest-value artifact.
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
again (their repo if they have one; otherwise default to
`~/Documents/writing-style/AI_comm_and_writing_style.md`); a short style
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

## Phase 5 — Digest and review prompt

Two condensations are generated from the finished directive, and both
are hand-maintained artifacts that must be reviewed against the
directive on every future edit — tell the user this plainly.

**The digest** (~60–80 tokens, injected with every prompt): declarative
statements only — text framed as system-voice commands can trip
prompt-injection defenses; name the highest-frequency rules (voice
adjectives, formatting bans, claims discipline), not everything; end by
noting the full directive is in the managed/user CLAUDE.md.

**The review prompt** (the judgment layer, evaluated by a small model at
the end of every turn): generate it from
`resources/review-prompt-template.md`. Keep the literal
`[writing-style-policy]` marker as the first characters — the
uninstallers identify our hook by it. Structure it as an ordered
decision list: exemptions first (explicit user request; mention rather
than use), violations after (only the checks the user's directive
actually imposes — decorative emoji, flattery openers, the banned-phrase
list from Phase 1), default pass last. Ordering matters: a flat clause
pile invites the evaluator to weigh clauses against each other; an
ordered list decides for it.

## Phase 6 — Deploy

**Check for an existing installation first.** Look for a managed-tier
policy (the managed directory exists with a CLAUDE.md) and for
user-tier entries (`outputStyle` or our hooks in
`~/.claude/settings.json`). If one exists, reuse its style name and tier
(this is a redeploy), or route through `style-uninstall` first —
deploying a user-tier policy under an existing managed one silently
never activates, because managed settings win.

**Licensing of what you generate.** The directive is the user's own work
and belongs solely to them: never write a license header, SPDX tag, or
copyright line into `canonical.md` or into the output-style file
deployed from it. When you copy the digest template into staging, drop
its entire leading comment block (the SPDX lines and the TEMPLATE note),
keeping only the shebang and the operational note. The review prompt you
generate carries no license text. Only the toolkit's own repository
files keep their headers; what lands in the user's environment is
header-free.

**Preflight.** The installers prefer `python3` for the settings merge;
confirm it executes — run `python3 -c 'import json'`, not a mere PATH
check, because a stock Mac without Command Line Tools has a stub that
resolves but fails. (There is no runtime python dependency; the review
layer is a prompt hook, not a script.) If python3 is unavailable, do
NOT stop — YOU perform the merge instead:

- *User tier*: read `~/.claude/settings.json`, merge the policy entries
  yourself (set `outputStyle`; add the digest command hook if absent;
  replace any marker-tagged Stop prompt hook with the new one), validate
  the result mechanically before writing — on macOS pipe it through
  `osascript -l JavaScript -e 'ObjC.import("Foundation"); const
  d=$.NSFileHandle.fileHandleWithStandardInput.readDataToEndOfFile;
  JSON.parse(ObjC.unwrap($.NSString.alloc.initWithDataEncoding(d,
  $.NSUTF8StringEncoding))); "ok"'` — back up the original, write the
  merged file, and place the remaining files by hand (canonical copy,
  import line, output style, digest hook), mirroring what
  `install-user.sh` does.
- *Managed tier*: the managed settings file is root-owned but
  world-readable, so read it, merge the fragment yourself (keep the
  `__CS_HOOKS_DIR__` placeholder in our entries — the installer
  substitutes it per-OS), validate as above, and pass the merged file as
  the fourth argument to `build-managed-installer.sh`. The emitted
  installer then writes your pre-merged result when the target machine
  lacks python3, instead of the lossy replace.

Model-merged JSON must always pass the mechanical validation before it
is written or embedded — never deploy a merge you have not validated.

**Stage** into an ephemeral `mktemp -d` directory with exactly three
files (the installers abort if any is missing): `canonical.md` (the
directive, no license header), `digest.sh` (from
`style-digest-template.sh`, comment block dropped, `__DIGEST_TEXT__`
replaced with the Phase 5 digest), `review-prompt.txt` (the Phase 5
review prompt, marker first).

**Sandbox-test the review prompt before deploying it.** Write a
throwaway settings file containing only a Stop prompt hook with the
generated prompt, then run two headless probes:
`claude -p --settings <file> "<instruction that produces a clear
violation, e.g. end the reply with two decorative star emoji>"` and
`claude -p --settings <file> "<instruction that produces a mention,
e.g. what is the code point of U+2B50, include the character>"`.
The violation case should come back revised or with the model surfacing
the block; the mention case should pass untouched. If the judgment is
wrong, fix the prompt's ordering or wording and retest — this is the
same discipline as testing the directive, applied to its enforcer.

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
  <staging-dir> "<Style Name>"`. It imports the directive into
  `~/.claude/CLAUDE.md` (append, never overwrite), installs the output
  style and sets `outputStyle`, deploys the digest hook, and merges the
  review prompt hook into `~/.claude/settings.json` (backup first;
  existing settings preserved). Fully automatic.
- **Managed tier**: run
  `${CLAUDE_PLUGIN_ROOT}/scripts/build-managed-installer.sh
  <staging-dir> "<Style Name>"`. It assembles ONE self-contained
  installer at `~/install_claude_writing_style.sh` with the directive,
  digest, and review-prompt settings fragment embedded inline
  (human-readable, inspectable before running). Tell the user to run, in
  a terminal, `sudo ~/install_claude_writing_style.sh`. If python3 works
  on the machine, the installer MERGES our fragment into any existing
  managed-settings.json (other managed settings preserved); without
  python3 it backs the file up and replaces it, and says so. It
  root-owns the tree and deletes itself on success.

After deploying, delete the staging directory on either tier. Explain
the four layers once, briefly: directive in CLAUDE.md (primacy, survives
compaction), same text as output style (system prompt, highest weight),
digest hook (recency, every prompt), judgment-review hook (a small model
reviews each reply against the rules with intent — it distinguishes
using a banned element from mentioning it). Name the covered surfaces:
local CLI sessions and the desktop app's Code and Cowork tabs; plain
desktop chat, web, and mobile are not reached by files on this machine.

## Phase 7 — Verify

Have the user fully quit and restart Claude Code — the output style and
managed settings are fixed at session start, and a `/clear` does not
reload them. Then, in the fresh session: ask Claude whether the
directive and output style are active (it can confirm both from its own
context); confirm the digest line arrives with a prompt; confirm the
review hook is registered (the marker-tagged prompt hook appears in the
tier's settings file) — its judgment was already sandbox-tested in
Phase 6, so no live violation test is needed. If the user works in a
desktop app, have them repeat the context check once in a Cowork or
Code tab session.

Record in a `VERIFIED.md` next to the canonical directive: what passed,
the style name, the tier, the canonical path, and the Phase 1 scenarios
(style-maintain reuses them).
