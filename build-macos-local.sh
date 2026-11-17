#!/usr/bin/env bash
# Build the encode (audio-encode) variant for *this* Mac into artifacts/.
# Prefer this over CI for darwin — Apple silicon only (Intel macOS not supported).
#
# Usage:
#   ./build-macos-local.sh
#   STAGE_MEDIATOOLS=1 ./build-macos-local.sh   # also copy bin/ffmpeg4ubii → ubii mediatools third_party
#
# Requires: curl, make, clang, nasm (brew install nasm).
set -euo pipefail

cd "$(dirname "$0")"
BASE_DIR=$(pwd)

case "$(uname -m)" in
	arm64)
		TARGET=arm64-apple-macos11
		MEDIATOOLS_PLAT=darwin-arm64
		;;
	*)
		echo "ffmpeg4ubii macOS builds require Apple silicon (arm64); got: $(uname -m)" >&2
		exit 1
		;;
esac

export TARGET
export FFMPEG_VARIANT=encode

echo "==> Building ffmpeg audio-encode for $TARGET"
./build-macos.sh

# Locate installed binary under artifacts/ (encode → ffmpeg4ubii; legacy trees may still have ffmpeg)
FF_BIN=$(find "$BASE_DIR/artifacts" -type f \( -name ffmpeg4ubii -o -name ffmpeg \) -path '*/bin/*' | head -1)
if [ -z "$FF_BIN" ] || [ ! -x "$FF_BIN" ]
then
	echo "ffmpeg binary missing under artifacts/" >&2
	exit 1
fi

if ! "$FF_BIN" -hide_banner -encoders 2>&1 | grep -q libopus
then
	echo "build missing libopus encoder: $FF_BIN" >&2
	exit 1
fi

echo "built $FF_BIN"
"$FF_BIN" -hide_banner -encoders 2>&1 | grep -E 'libopus|libmp3lame' || true

if [ "${STAGE_MEDIATOOLS:-}" = "1" ]
then
	DEST_ROOT="${MEDIATOOLS_ROOT:-$BASE_DIR/../mediatools/third_party/ffmpeg/$MEDIATOOLS_PLAT}"
	mkdir -p "$DEST_ROOT"
	cp -f "$FF_BIN" "$DEST_ROOT/ffmpeg4ubii"
	chmod 755 "$DEST_ROOT/ffmpeg4ubii"
	cat >"$DEST_ROOT/README.txt" <<EOF
ffmpeg4ubii from ubii-stack/ffmpeg-build (encode + static libopus).
Built locally: ./build-macos-local.sh (STAGE_MEDIATOOLS=1).
EOF
	echo "staged $DEST_ROOT/ffmpeg4ubii"
fi
