#!/usr/bin/env bash
# Post-build checks for audio-encode (libopus). Cross-built Windows PE files cannot
# run on Linux — grep the binary instead of executing -encoders.
set -euo pipefail

ff="${1:?ffmpeg binary path}"
if [ ! -f "$ff" ]; then
	echo "missing binary: $ff" >&2
	exit 1
fi

if file "$ff" 2>/dev/null | grep -qE 'ELF .* x86-64'; then
	"$ff" -hide_banner -encoders 2>&1 | grep -q libopus
	echo "ok native libopus in $ff"
	exit 0
fi

if file "$ff" 2>/dev/null | grep -qE 'ELF .* aarch64'; then
	# e.g. linux arm64 cross — do not execute on amd64 host
	grep -aq libopus "$ff" || grep -aq 'Opus (codec opus)' "$ff"
	echo "ok libopus markers in $ff (cross ELF)"
	exit 0
fi

if file "$ff" 2>/dev/null | grep -qi 'PE32'; then
	grep -aq libopus "$ff" || grep -aq 'libopus Opus' "$ff" || grep -aq 'encoder=libopus' "$ff"
	echo "ok libopus markers in $ff (PE)"
	exit 0
fi

# Fallback
grep -aq libopus "$ff" || {
	echo "could not verify libopus in $ff ($(file -b "$ff" 2>/dev/null || true))" >&2
	exit 1
}
echo "ok libopus markers in $ff"