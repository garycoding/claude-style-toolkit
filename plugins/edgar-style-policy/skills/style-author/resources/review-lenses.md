<!--
SPDX-FileCopyrightText: 2026 Gary Frattarola

SPDX-License-Identifier: MIT OR Apache-2.0
-->

# Fresh-eyes review lenses

Spawn each as an independent subagent with NO conversation context.
Replace {DOC_PATH} with the draft's path and {SCENARIOS} with 4–5 real
scenarios collected in intake. Instruct every reviewer: report only
findings you would defend; proposals must be minimal — one sentence or
one example pair; trimming counts as much as adding; rank by importance.
Give each reviewer the template definition (rule / test / one example
pair, self-testing rules exempt) and the calibration principle verbatim.

## Lens 1 — Template audit

Read {DOC_PATH}. Classify every rule: has a test? has an example pair?
carries more examples than the one-or-two ceiling? Report only deviations
that matter, with a minimal addition or trim for each. A list of
categories is not an example; quoted phrases are.

## Lens 2 — Cold read

Read {DOC_PATH} as a model receiving it at session start. Report: (a)
instructions ambiguous in a real situation — name the situation; (b)
rules that pull against each other with no stated resolution; (c)
omissions a global style directive needs, judged strictly; (d)
self-compliance — places the document violates its own rules. Quote
exactly. Do not re-litigate deliberate design decisions.

## Lens 3 — Compliance simulation

Read {DOC_PATH}. Apply it to these scenarios: {SCENARIOS}. For each,
state what the document commands, where two commands collide, and where
it is silent but should not be. Include at least one scenario with
pressure to violate the substance rules (e.g., "make it exciting") and
report whether the document resolves it decidably.
