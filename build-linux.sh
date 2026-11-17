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

OUTPUT_DIR=artifacts/ffmpeg-$FFMPEG_VERSION-$FFMPEG_VARIANT_LABEL-$ARCH-linux-gnu

# Per-target arguments for build-lame.sh (used by the encode variant).
LAME_CONFIGURE_ARGS=(CFLAGS=-fPIC)

case $ARCH in
    x86_64)
        ;;
    i686)
        FFMPEG_CONFIGURE_FLAGS+=(--cc="gcc -m32")
        LAME_CONFIGURE_ARGS=(--host=i686-linux-gnu "CC=gcc -m32" "CFLAGS=-fPIC -m32")
        ;;
    arm64)
        FFMPEG_CONFIGURE_FLAGS+=(
            --enable-cross-compile
            --cross-prefix=aarch64-linux-gnu-
            --target-os=linux
            --arch=aarch64
            --cc=aarch64-linux-gnu-gcc
        )
        LAME_CONFIGURE_ARGS+=(
            --host=aarch64-linux-gnu
            CC=aarch64-linux-gnu-gcc
            AR=aarch64-linux-gnu-ar
            RANLIB=aarch64-linux-gnu-ranlib
        )
        ;;
    arm*)
        FFMPEG_CONFIGURE_FLAGS+=(
            --enable-cross-compile
            --cross-prefix=arm-linux-gnueabihf-
            --target-os=linux
            --arch=arm
        )
        LAME_CONFIGURE_ARGS+=(--host=arm-linux-gnueabihf)
        case $ARCH in
            armv7-a)
                FFMPEG_CONFIGURE_FLAGS+=(
                    --cpu=armv7-a
                )
                ;;
            armv8-a)
                FFMPEG_CONFIGURE_FLAGS+=(
                    --cpu=armv8-a
                )
                ;;
            armhf-rpi2)
                FFMPEG_CONFIGURE_FLAGS+=(
                    --cpu=cortex-a7
                    --extra-cflags='-fPIC -mcpu=cortex-a7 -mfloat-abi=hard -mfpu=neon-vfpv4 -mvectorize-with-neon-quad'
                )
                ;;
            armhf-rpi3)
                FFMPEG_CONFIGURE_FLAGS+=(
                    --cpu=cortex-a53
                    --extra-cflags='-fPIC -mcpu=cortex-a53 -mfloat-abi=hard -mfpu=neon-fp-armv8 -mvectorize-with-neon-quad'
                )
                ;;
        esac
        ;;
    *)
        echo "Unknown architecture: $ARCH"
        exit 1
        ;;
esac

BUILD_DIR=$(mktemp -d -p $(pwd) build.XXXXXXXX)
DEPS_DIR=$(mktemp -d -p $(pwd) deps.XXXXXXXX)
trap 'rm -rf $BUILD_DIR $DEPS_DIR' EXIT

DEPS_CFLAGS=
DEPS_LDFLAGS=
if [ "$FFMPEG_VARIANT" = encode ]
then
    echo "Building static libmp3lame for $ARCH" >&2
    LAME_PREFIX=$DEPS_DIR ./build-lame.sh "${LAME_CONFIGURE_ARGS[@]}" \
        || { echo "build-lame failed" >&2; exit 1; }
    echo "Building static libopus for $ARCH" >&2
    OPUS_PREFIX=$DEPS_DIR ./build-opus.sh "${LAME_CONFIGURE_ARGS[@]}" \
        || { echo "build-opus failed" >&2; exit 1; }
    if [ ! -f "$DEPS_DIR/lib/libopus.a" ]; then
        echo "libopus static library missing under $DEPS_DIR/lib" >&2
        exit 1
    fi
    export PKG_CONFIG_PATH="$DEPS_DIR/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
    export PKG_CONFIG_LIBDIR="$DEPS_DIR/lib/pkgconfig"
    export PKG_CONFIG="${PKG_CONFIG:-pkg-config}"
    DEPS_CFLAGS="-I$DEPS_DIR/include"
    DEPS_LDFLAGS="-L$DEPS_DIR/lib"
    FFMPEG_CONFIGURE_FLAGS+=(
        --pkg-config=pkg-config
        --pkg-config-flags=--static
    )
fi

cd $BUILD_DIR
tar --strip-components=1 -xf $BASE_DIR/$FFMPEG_TARBALL

EXTRA_CFLAGS='-fPIC'
COMBINED_CFLAGS="$EXTRA_CFLAGS"
if [ -n "$DEPS_CFLAGS" ]; then
    COMBINED_CFLAGS="$DEPS_CFLAGS ${COMBINED_CFLAGS# }"
fi
COMBINED_LDFLAGS="$DEPS_LDFLAGS"

FFMPEG_CONFIGURE_FLAGS+=(
    --prefix=$BASE_DIR/$OUTPUT_DIR
    --extra-cflags="$COMBINED_CFLAGS"
)
if [ -n "$COMBINED_LDFLAGS" ]; then
    FFMPEG_CONFIGURE_FLAGS+=(--extra-ldflags="$COMBINED_LDFLAGS")
fi

./configure "${FFMPEG_CONFIGURE_FLAGS[@]}" || (tail -n 80 ffbuild/config.log && exit 1)

make
make install

FF_BIN="$BASE_DIR/$OUTPUT_DIR/bin/ffmpeg"
if [ -f "$FF_BIN" ]; then
	mv "$FF_BIN" "$BASE_DIR/$OUTPUT_DIR/bin/ffmpeg4ubii"
fi

if stat -c '%u:%g' "$BASE_DIR" >/dev/null 2>&1; then
    chown "$(stat -c '%u:%g' "$BASE_DIR")" -R "$BASE_DIR/$OUTPUT_DIR"
fi
