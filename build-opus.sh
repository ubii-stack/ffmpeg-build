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

./configure \
	--prefix="$OPUS_PREFIX" \
	--enable-static \
	--disable-shared \
	--disable-extra-programs \
	--disable-doc \
	"$@"

make
make install

test -f "$OPUS_PREFIX/lib/libopus.a" -o -f "$OPUS_PREFIX/lib/libopus.lib"
