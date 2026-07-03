<!--
SPDX-FileCopyrightText: 2026 Gary Frattarola

SPDX-License-Identifier: MIT OR Apache-2.0
-->

# Third-Party Licenses

claude-style-toolkit has **no third-party dependencies**. It is composed
entirely of:

- Markdown (the skills, templates, and documentation), and
- bash scripts (the installers, uninstallers, and the digest hook
  template); the installers and uninstallers run inline Python at
  install/uninstall time for the settings merge, importing only the
  Python standard library (`json`, `os`, `sys`).

Nothing is vendored, bundled, or fetched at install time, and nothing the
toolkit deploys depends on Python at runtime. The installers write only to
the user's own Claude Code configuration locations. There are therefore
no third-party license obligations to document.

Should a future version add a dependency, list it here grouped by license, and
prefer permissively licensed libraries (MIT / BSD / Apache / ISC) consistent
with this project's own `MIT OR Apache-2.0` terms.
