<!--
SPDX-FileCopyrightText: 2026 Gary Frattarola

SPDX-License-Identifier: MIT OR Apache-2.0
-->

# In-flight ideas

Ideas under consideration for the toolkit: each is a question, not a
commitment, to be researched, weighed, and then planned or dropped.

## Deliver the hooks from the plugin itself

Recorded 25 September 2026, during the review that introduced the layer
record. Claude Code plugins can now ship hooks (`hooks/hooks.json`) and
output styles, and managed settings can force-enable a plugin through
`enabledPlugins`. A plugin cannot ship a CLAUDE.md. After the September
changes a style deploys the directive (a file), the digest hook and, for
some styles, the commit emoji check; the two hooks could ship inside the
plugin, so that no settings file is merged for them and the JSON engine
ladder shrinks to the managed tier and the fallback.

Open questions before it is worth building:

- The digest differs per style, so a plugin hook would need to know which
  style is active (for example by matching the deployed directive, as the
  skills now do, or from a file the installers write).
- At the managed tier, tamper resistance would depend on managed settings
  force-enabling the plugin, which is untested here.
- Whether hooks from a locally installed plugin load in Cowork. A plugin
  installed through Cowork's Customize panel is documented to carry hooks
  and skills there, which would be the only route into Cowork without
  sudo; the user tier, which writes to `~/.claude`, does not reach Cowork.
