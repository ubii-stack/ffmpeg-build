#!/usr/bin/env bash

set -eu

cd $(dirname $0)
BASE_DIR=$(pwd)

source common.sh

if [ ! -e $FFMPEG_TARBALL ]
then
	curl -s -L -O $FFMPEG_TARBALL_URL
fi

: ${ARCH?}

# Normalize aliases. Mingw triples use aarch64 (not arm64).
case $ARCH in
	x86_64|i686)
		;;
	arm64|aarch64)
		ARCH=aarch64
		;;
	*)
		echo "Unknown Windows architecture: $ARCH (expected x86_64, i686, or aarch64/arm64)" >&2
		exit 1
		;;
esac

CROSS_PREFIX=$ARCH-w64-mingw32-
if ! command -v ${CROSS_PREFIX}gcc >/dev/null 2>&1
then
	echo "Missing cross compiler: ${CROSS_PREFIX}gcc" >&2
	if [ "$ARCH" = aarch64 ]
	then
		echo "Ubuntu apt mingw-w64 has no Windows ARM64 target." >&2
		echo "Install llvm-mingw and put its bin/ on PATH, e.g.:" >&2
		echo "  https://github.com/mstorsjo/llvm-mingw/releases" >&2
		echo "  (ucrt-ubuntu-*-x86_64.tar.xz on amd64 Linux CI)" >&2
	else
		echo "On Ubuntu: sudo apt-get install -y mingw-w64" >&2
	fi
	exit 1
fi

OUTPUT_DIR=artifacts/ffmpeg-$FFMPEG_VERSION-$FFMPEG_VARIANT_LABEL-$ARCH-w64-mingw32

BUILD_DIR=$(mktemp -d -p $(pwd) build.XXXXXXXX)
DEPS_DIR=$(mktemp -d -p $(pwd) deps.XXXXXXXX)
trap 'rm -rf $BUILD_DIR $DEPS_DIR' EXIT

if [ "$FFMPEG_VARIANT" = encode ]
then
	LAME_PREFIX=$DEPS_DIR ./build-lame.sh --host=$ARCH-w64-mingw32
	OPUS_PREFIX=$DEPS_DIR ./build-opus.sh --host=$ARCH-w64-mingw32
	export PKG_CONFIG_PATH="$DEPS_DIR/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
	export PKG_CONFIG_LIBDIR="$DEPS_DIR/lib/pkgconfig"
	FFMPEG_CONFIGURE_FLAGS+=(
		--extra-cflags=-I$DEPS_DIR/include
		--extra-ldflags=-L$DEPS_DIR/lib
		--pkg-config-flags=--static
	)
fi

cd $BUILD_DIR
tar --strip-components=1 -xf $BASE_DIR/$FFMPEG_TARBALL

# gcc mingw (x86): static-libgcc. llvm-mingw (aarch64): plain -static is enough.
if [ "$ARCH" = aarch64 ]
then
	EXTRA_CFLAGS='-static'
	EXTRA_LDFLAGS='-static'
else
	EXTRA_CFLAGS='-static -static-libgcc -static-libstdc++'
	EXTRA_LDFLAGS=''
fi

FFMPEG_CONFIGURE_FLAGS+=(
	--prefix=$BASE_DIR/$OUTPUT_DIR
	--extra-cflags="$EXTRA_CFLAGS"
	--enable-cross-compile
	--target-os=mingw32
	--arch=$ARCH
	--cross-prefix=$CROSS_PREFIX
)

if [ -n "$EXTRA_LDFLAGS" ]
then
	FFMPEG_CONFIGURE_FLAGS+=(--extra-ldflags="$EXTRA_LDFLAGS")
fi

./configure "${FFMPEG_CONFIGURE_FLAGS[@]}" || (cat ffbuild/config.log && exit 1)
make
make install

chown $(stat -c '%u:%g' $BASE_DIR) -R $BASE_DIR/$OUTPUT_DIR
