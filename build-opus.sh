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
	curl -s -L -o "$OPUS_TARBALL" "$OPUS_TARBALL_URL"
fi

BUILD_DIR=$(mktemp -d -p "$(pwd)" opus.XXXXXXXX)
trap 'rm -rf $BUILD_DIR' EXIT

cd "$BUILD_DIR"
tar --strip-components=1 -xf "$BASE_DIR/$OPUS_TARBALL"

./configure \
	--prefix="$OPUS_PREFIX" \
	--enable-static \
	--disable-shared \
	--disable-extra-programs \
	--disable-doc \
	"$@"

make
make install
