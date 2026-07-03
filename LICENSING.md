<!--
SPDX-FileCopyrightText: 2026 Gary Frattarola

SPDX-License-Identifier: MIT OR Apache-2.0
-->

# Licensing

Copyright © 2026 **Gary Frattarola**.

## How this project is licensed

claude-style-toolkit is licensed under **either of**, at your option:

- the **MIT** license ([`LICENSE-MIT`](LICENSE-MIT); full text also in
  [`LICENSES/MIT.txt`](LICENSES/MIT.txt)), or
- the **Apache License, Version 2.0** ([`LICENSE-APACHE`](LICENSE-APACHE); full
  text also in [`LICENSES/Apache-2.0.txt`](LICENSES/Apache-2.0.txt)).

In SPDX terms: `MIT OR Apache-2.0`. You may use, modify, and distribute this
software under the terms of whichever of the two licenses you prefer.

### Contribution

Unless you explicitly state otherwise, any contribution intentionally submitted
for inclusion in the work by you shall be dual-licensed as above (`MIT OR
Apache-2.0`), without any additional terms or conditions.

## What the license does and does not cover

The license covers this repository: the skills, the directive template, the
review lenses, the hook script templates, and the installers. It is the tooling.

It does **not** cover the writing-style directive a user produces by running the
`style-author` skill. That document — the user's `AI_comm_and_writing_style.md`
and the copies the installer deploys from it — is the user's own work and
belongs solely to them. The skill is instructed never to write a license header
into a generated directive. The digest text and the judgment-review prompt a
user's session generates are likewise their content — one embedded in the
deployed digest hook, the other in their settings configuration; the license
here applies to the surrounding harness code, not to that content.

## REUSE compliance

This repo is [REUSE](https://reuse.software/)-compliant: every file declares its
license via an SPDX header or a [`REUSE.toml`](REUSE.toml) annotation. Verify
with:

```bash
uvx --from "reuse[charset-normalizer]" reuse lint
```
