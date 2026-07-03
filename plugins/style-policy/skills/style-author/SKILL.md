---
name: style-author
description: Guide the user through authoring a personal or company writing-style directive for Claude — starting from an interview or from the user's exemplar documents — then review it for contradictions, run a fresh-eyes multi-agent review, generate the per-prompt digest, and deploy the policy to Claude Code (user-tier, no sudo, or managed tier). Use when the user wants to create, bootstrap, review, or install a writing style policy or style guide for AI output.
---

# Style-directive authoring and deployment

You are guiding the user through producing a writing-style directive that
Claude will actually follow, then deploying it as layered policy. The
process has seven phases. Work one decision per exchange: present a
finding or a draft, get the user's verdict, apply it, move on. Never
apply unapproved changes to their directive.

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
full before drafting. Phase 1 then fills only the gaps the material does
not already answer.

## Phase 1 — Intake interview

Collect, in the user's own words — but skip anything the exemplars or the
existing draft already establish, and confirm rather than re-ask it:

- Voice: five or six adjectives, and — more useful — what AI output has
  done wrong for them before (specific irritations become rules).
- Audiences and deliverable types (each may need a scope clause).
- Banned words and phrases — get the literal list; it feeds both the
  Diction section and the deterministic lint (see Phase 6). For a PR or
  marketing user this list is often the highest-value artifact.
- Claims policy: what may be asserted, what needs evidence, how
  uncertainty is expressed. (For commercial writing: what counts as an
  inflated claim.)
- Formatting: lists vs prose, emphasis, emojis, headings, length norms.
- Correspondence: whether greetings/thanks/sign-offs are structure to
  keep (they usually are).
- Whether output in other languages should follow the same standards.

## Phase 2 — First draft

Synthesize the exemplars, any existing draft, and the interview into a
complete first draft of the user's `AI_comm_and_writing_style.md`, using
`resources/directive-template.md` as the skeleton. Keep the user's
wording where it is precise; upgrade it to the rule/test/example-pair
template where it is vague. Include the standard closing sections from
the template (Scope and precedence, Formatting, Compact Instructions) —
they exist because their absence is a known failure mode, but adapt their
content to the user.

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
self-violations), and a compliance simulator (apply the directive to
4–5 of the user's real scenarios, collected in Phase 1). Discard
findings that would bloat the document; present survivors ranked, and
apply only what the user approves.

The back-and-forth ends when the user is satisfied, not when this phase
completes. After substantial changes, offer another fresh-eyes pass, and
keep refining — review findings or freeform edits — until the user
confirms the document is right. Only then continue to Phase 5.

## Phase 5 — Digest

Write a one-paragraph condensation (~60–80 tokens) for per-prompt
re-injection. Rules: declarative statements only — text framed as
system-voice commands can trip prompt-injection defenses; name the
highest-frequency rules (voice adjectives, formatting bans, claims
discipline), not everything; end by noting the full directive is in the
managed/user CLAUDE.md. Tell the user plainly: this digest is the one
hand-maintained condensation in the system — every future edit to the
directive requires reviewing the digest against it.

## Phase 6 — Deploy

**Licensing of what you generate.** The directive is the user's own
work and belongs solely to them: never write a license header, SPDX tag,
or copyright line into `canonical.md` or into the output-style file
deployed from it. When you copy the two script templates into the
staging directory, drop their leading SPDX header comment lines — the
deployed hooks are the user's private configuration (they embed the
user's directive digest and banned-phrase list), not redistributed
toolkit files. The toolkit's own repository files keep their headers;
only what lands in the user's environment is header-free.

The plugin's shared scripts live at `${CLAUDE_PLUGIN_ROOT}/scripts/`.
Assemble a staging directory: `canonical.md` (the directive, no license
header), `digest.sh` (from `style-digest-template.sh`, digest text
inserted, SPDX header dropped), `lint.py` (from `style-lint-template.py`,
the banned-phrase list from Phase 1 inserted into BANNED_PHRASES, SPDX
header dropped). Then:

**Ask the user which tier they want before deploying — do not choose for
them.** Present the trade-off in one exchange: the user tier is fully
automatic and needs no password, but nothing in `~/.claude` is
tamper-resistant, so any tool that writes there (including Claude's own
memory feature) could alter the policy; the managed tier is root-owned
and cannot be overridden or edited without elevation, but it requires the
user to run one `sudo` command in a terminal, since the harness cannot
enter passwords. Recommend the user tier for a personal machine where the
concern is drift rather than tampering, and the managed tier for anyone
who wants the policy frozen. Deploy only the tier they choose.

Stage into an ephemeral directory (`mktemp -d`), not the home directory
or the repo. Then, by the chosen tier:

- **Default — user tier, no sudo**: run
  `${CLAUDE_PLUGIN_ROOT}/scripts/install-user.sh <staging-dir> "<Style Name>"`.
  It imports the directive into `~/.claude/CLAUDE.md` (append, never
  overwrite), installs the output style and sets `outputStyle`, and
  merges both hooks into `~/.claude/settings.json` (with backup). Fully
  automatic. Honest limitation to state: nothing is tamper-resistant —
  any tool writing to `~/.claude` can alter it.
- **Optional — managed tier (sudo)**: run
  `${CLAUDE_PLUGIN_ROOT}/scripts/build-managed-installer.sh <staging-dir> "<Style Name>"`.
  It assembles ONE self-contained installer at
  `~/install_claude_writing_style.sh` with the directive, digest, and
  lint embedded inline (human-readable, so the user can inspect the sudo
  script first). Then delete the `mktemp` staging directory — nothing
  else needs to persist. Tell the user to run, in a terminal,
  `sudo ~/install_claude_writing_style.sh`; it writes the policy
  root-owned and deletes itself on success. No other files land in the
  home directory, and the only residue is a timestamped backup of any
  prior `managed-settings.json`, left in the managed directory by design.
  The harness cannot enter passwords, which is why this last step is the
  user's to run.

Explain the four layers once, briefly: directive in CLAUDE.md (primacy,
survives compaction), same text as output style (system prompt, highest
weight), digest hook (recency, every prompt), lint hook (deterministic,
no attention decay).

## Phase 7 — Verify

In a fresh session after install: ask Claude whether the directive and
output style are active (it can confirm from its own context); confirm
the digest line arrives with a prompt; test the lint by requesting
output that violates a banned rule and confirming the reply gets
blocked into revision. If the user works in a desktop app, have them
repeat the context check once in a Cowork or Code tab session. Record
what passed in the staging directory's `VERIFIED.md`.
