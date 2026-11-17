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
	x86_64)
		;;
	arm64|aarch64)
		ARCH=aarch64
		;;
	*)
		echo "Unknown Windows architecture: $ARCH (expected x86_64 or aarch64/arm64)" >&2
		exit 1
		;;
esac

CROSS_PREFIX=$ARCH-w64-mingw32-
export PKG_CONFIG="${PKG_CONFIG:-pkg-config}"
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

DEPS_CFLAGS=
DEPS_LDFLAGS=
if [ "$FFMPEG_VARIANT" = encode ]
then
	MINGW_HOST=$ARCH-w64-mingw32
	DEPS_CONFIGURE_ARGS=(
		--host=$MINGW_HOST
		CC=${CROSS_PREFIX}gcc
		AR=${CROSS_PREFIX}ar
		RANLIB=${CROSS_PREFIX}ranlib
	)
	echo "Building static libmp3lame for $MINGW_HOST" >&2
	LAME_PREFIX=$DEPS_DIR ./build-lame.sh "${DEPS_CONFIGURE_ARGS[@]}" \
		|| { echo "build-lame failed" >&2; exit 1; }
	echo "Building static libopus for $MINGW_HOST" >&2
	OPUS_PREFIX=$DEPS_DIR ./build-opus.sh "${DEPS_CONFIGURE_ARGS[@]}" \
		|| { echo "build-opus failed" >&2; exit 1; }
	if [ ! -f "$DEPS_DIR/lib/libopus.a" ] \
		&& [ ! -f "$DEPS_DIR/lib/libopus.lib" ] \
		&& [ ! -f "$DEPS_DIR/lib/libopus.dll.a" ]
	then
		echo "libopus static library missing under $DEPS_DIR/lib" >&2
		ls -la "$DEPS_DIR/lib" >&2 || true
		exit 1
	fi
	export PKG_CONFIG_PATH="$DEPS_DIR/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
	export PKG_CONFIG_LIBDIR="$DEPS_DIR/lib/pkgconfig"
	DEPS_CFLAGS="-I$DEPS_DIR/include"
	DEPS_LDFLAGS="-L$DEPS_DIR/lib"
	FFMPEG_CONFIGURE_FLAGS+=(
		--pkg-config=pkg-config
		--pkg-config-flags=--static
	)
fi

cd $BUILD_DIR
tar --strip-components=1 -xf $BASE_DIR/$FFMPEG_TARBALL

# Fully static PE (llvm-mingw / mingw-w64).
EXTRA_CFLAGS='-static'
EXTRA_LDFLAGS='-static'

COMBINED_CFLAGS="$EXTRA_CFLAGS"
if [ -n "$DEPS_CFLAGS" ]
then
	COMBINED_CFLAGS="$DEPS_CFLAGS ${COMBINED_CFLAGS# }"
fi
COMBINED_LDFLAGS="$EXTRA_LDFLAGS"
if [ -n "$DEPS_LDFLAGS" ]
then
	COMBINED_LDFLAGS="$DEPS_LDFLAGS${COMBINED_LDFLAGS:+ $COMBINED_LDFLAGS}"
fi

FFMPEG_CONFIGURE_FLAGS+=(
	--prefix=$BASE_DIR/$OUTPUT_DIR
	--extra-cflags="$COMBINED_CFLAGS"
	--enable-cross-compile
	--target-os=mingw32
	--arch=$ARCH
	--cross-prefix=$CROSS_PREFIX
	--cc=${CROSS_PREFIX}gcc
)

if [ -n "$COMBINED_LDFLAGS" ]
then
	FFMPEG_CONFIGURE_FLAGS+=(--extra-ldflags="$COMBINED_LDFLAGS")
fi

./configure "${FFMPEG_CONFIGURE_FLAGS[@]}" || (cat ffbuild/config.log && exit 1)
make
make install

# Ship ubii-branded encoder name (ffprobe stays ffmpeg.exe tooling name).
BIN_DIR="$BASE_DIR/$OUTPUT_DIR/bin"
if [ -f "$BIN_DIR/ffmpeg.exe" ]
then
	mv "$BIN_DIR/ffmpeg.exe" "$BIN_DIR/ffmpeg4ubii.exe"
fi

if stat -c '%u:%g' "$BASE_DIR" >/dev/null 2>&1
then
	chown "$(stat -c '%u:%g' "$BASE_DIR")" -R "$BASE_DIR/$OUTPUT_DIR"
fi
