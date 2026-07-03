<!--
SPDX-FileCopyrightText: 2026 Gary Frattarola

SPDX-License-Identifier: MIT OR Apache-2.0
-->

# Third-Party Licenses

claude-style-toolkit has **no third-party dependencies**. It is composed
entirely of:

- Markdown (the skills, templates, and documentation),
- POSIX shell scripts (the installers and the digest hook template), and
- a Python script (the lint hook template) that imports only the Python
  standard library (`json`, `re`, `sys`, `os`).

Nothing is vendored, bundled, or fetched at install time. The installers write
only to the user's own Claude Code configuration locations. There are therefore
no third-party license obligations to document.

Should a future version add a dependency, list it here grouped by license, and
prefer permissively licensed libraries (MIT / BSD / Apache / ISC) consistent
with this project's own `MIT OR Apache-2.0` terms.
