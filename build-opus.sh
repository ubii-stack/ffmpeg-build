#!/usr/bin/env bash

# Builds a static libopus into $OPUS_PREFIX. Extra args go to Opus configure
# (toolchain: --host, CC=..., CFLAGS=…), same pattern as build-lame.sh.

set -eu

cd "$(dirname "$0")"
BASE_DIR=$(pwd)

source common.sh

: "${OPUS_PREFIX?}"

if [ ! -e "$OPUS_TARBALL" ]
then
	echo "Downloading $OPUS_TARBALL_URL" >&2
	curl -fL --retry 3 --retry-delay 2 -o "$OPUS_TARBALL" "$OPUS_TARBALL_URL"
fi

# mktemp -p is GNU; fall back for macOS.
if BUILD_DIR=$(mktemp -d -p "$(pwd)" opus.XXXXXXXX 2>/dev/null)
then
	:
else
	BUILD_DIR=$(mktemp -d "$(pwd)/opus.XXXXXXXX")
fi
trap 'rm -rf $BUILD_DIR' EXIT

cd "$BUILD_DIR"
tar --strip-components=1 -xf "$BASE_DIR/$OPUS_TARBALL"

if [ ! -x ./configure ]
then
	echo "opus tarball missing ./configure" >&2
	exit 1
fi

OPUS_EXTRA=()
case " $* " in
	*"mingw"*)
		# Cross to Windows: avoid host RTCD / feature probes that fail or lie under cross.
		OPUS_EXTRA+=(--disable-rtcd)
		case " $* " in
			*x86_64*)
				# Linux-hosted nasm/objfmt does not match PE; use portable C for x86 Windows.
				OPUS_EXTRA+=(--disable-asm --disable-intrinsics)
				;;
		esac
		;;
esac

./configure \
	--prefix="$OPUS_PREFIX" \
	--enable-static \
	--disable-shared \
	--disable-extra-programs \
	--disable-doc \
	"${OPUS_EXTRA[@]}" \
	"$@"

make
make install

if [ ! -f "$OPUS_PREFIX/lib/libopus.a" ] && [ ! -f "$OPUS_PREFIX/lib/libopus.lib" ]
then
	echo "libopus not installed under $OPUS_PREFIX/lib" >&2
	exit 1
fi
