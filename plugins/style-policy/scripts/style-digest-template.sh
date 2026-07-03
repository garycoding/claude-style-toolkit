#!/bin/bash
# UserPromptSubmit hook: injects a compact digest of the style directive
# with every prompt, giving the rules a recency position each turn.
#
# NOTE: the digest below is a HAND-MAINTAINED condensation of the
# canonical directive — the one artifact that can drift from the source.
# Review it against the directive on every canonical edit. Keep it
# declarative: system-voice commands in injected context can trip
# prompt-injection defenses. Target 60–80 tokens.
cat <<'EOF'
__DIGEST_TEXT__
EOF
exit 0
