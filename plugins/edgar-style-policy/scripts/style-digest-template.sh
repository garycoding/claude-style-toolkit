#!/bin/bash
# SPDX-FileCopyrightText: 2026 Gary Frattarola
# SPDX-License-Identifier: MIT OR Apache-2.0
#
# TEMPLATE (toolkit file, licensed as above). When the style-author skill
# stages the deployed digest.sh, it drops these SPDX header lines: the deployed
# hook is the user's private configuration and embeds the user's own directive
# digest, not a redistributed toolkit file.
#
# UserPromptSubmit hook: injects a compact digest of the style directive
# with every prompt, giving the rules a recency position each turn.
#
# NOTE: the digest below is a HAND-MAINTAINED condensation of the
# canonical directive — the one artifact that can drift from the source.
# Review it against the directive on every canonical edit. Keep it
# declarative: system-voice commands in injected context can trip
# prompt-injection defenses. Target 60–80 tokens. The digest text must not
# contain a line consisting solely of "EOF" — it would terminate the heredoc
# below early and truncate the deployed hook.
cat <<'EOF'
__DIGEST_TEXT__
EOF
exit 0
