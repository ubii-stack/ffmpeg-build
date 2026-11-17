ffmpeg4ubii
===========

Static FFmpeg builds for **ubii** (audio-encode today; room to grow toward
video later). This project contains scripts for small static audio-only FFmpeg builds. The
default builds are used for Chromaprint packaging (`fpcalc`), and there is an
additional variant that can also encode audio (including **libopus** for Ubii
LAN music sync).

Building is done using GitHub Actions for **Linux** and **Windows**. **macOS**
is built locally (see below). Built binaries are on the releases page.

The current FFmpeg version is **8.1.2**. The builds are LGPL-licensed (no
`--enable-gpl` or `--enable-nonfree`).

Variants
--------

Each platform is built in two variants, selected with the `FFMPEG_VARIANT`
environment variable:

  - `decode` (default, output label `audio`) — audio **decoders** only, as
    needed by Chromaprint. This is the small, fully self-contained build.
  - `encode` (output label `audio-encode`) — everything in `decode` plus audio
    **encoders** and muxers for transcoding:
      * MP3 via statically linked [LAME](https://lame.sourceforge.io/)
        (`build-lame.sh`)
      * Opus via statically linked [libopus](https://opus-codec.org/)
        (`build-opus.sh`) — **required**; FFmpeg’s experimental native Opus
        encoder produces scrambled audio and is not enabled

Supported platforms:

  - Linux (GitHub Actions)
      * `x86_64-linux-gnu`
      * `arm64-linux-gnu`
  - Windows (GitHub Actions)
      * `x86_64-w64-mingw32`
      * `aarch64-w64-mingw32` (Windows on ARM; llvm-mingw)
  - macOS (local, Apple silicon only)
      * `arm64-apple-macos11`

CI workflows
------------

  - `.github/workflows/build-linux-encode.yml` — Linux **audio-encode**
    (x86_64, arm64). Tag `v*` + workflow_dispatch → release `.tar.gz`.
  - `.github/workflows/build-windows-encode.yml` — Windows **audio-encode**
    (x86_64, aarch64 / llvm-mingw). **workflow_dispatch only** while Linux
    CI is active; tag builds publish `ffmpeg4ubii.exe` releases when re-enabled.
  - `.github/workflows/build-windows-arm64.yml` — legacy; arm64 is in
    `build-windows-encode.yml`.

macOS is **not** in CI by default — use the local script on an Apple machine.

GitHub Releases
---------------

Release **assets** (`.tar.gz` per platform/variant) are uploaded when you push a
version tag matching `v*`, for example:

```sh
git tag v8.1.2-2
git push origin main v8.1.2-2   # main updates remote; CI runs once (tag only)
```

Each tarball unpacks to a prefix directory such as
`ffmpeg-8.1.2-audio-encode-aarch64-w64-mingw32/` with `bin/ffmpeg` or
`bin/ffmpeg4ubii.exe` (Windows; `bin/ffmpeg` on Linux).

**One-time repo setup (required for releases):**

1. Open **Settings → Actions → General → Workflow permissions**
2. Choose **Read and write permissions**. Save.

Building locally
----------------

### macOS (recommended for Darwin)

```sh
# encode + static libopus → artifacts/…
./build-macos-local.sh

# also copy to ubii mediatools third_party as ffmpeg-audio:
STAGE_MEDIATOOLS=1 ./build-macos-local.sh
```

Requires `nasm` (`brew install nasm`). Builds LAME + libopus from source (no
Homebrew opus dylib).

### Linux / Windows (or macOS via TARGET)

```sh
ARCH=x86_64 FFMPEG_VARIANT=encode ./build-linux.sh
ARCH=x86_64 FFMPEG_VARIANT=encode ./build-windows.sh   # llvm-mingw on PATH

# macOS Apple silicon only:
TARGET=arm64-apple-macos11 FFMPEG_VARIANT=encode ./build-macos.sh

# Windows ARM64 (llvm-mingw bin/ on PATH):
ARCH=aarch64 FFMPEG_VARIANT=encode ./build-windows.sh
```

The resulting tree is placed under `artifacts/`.

Ubii mediatools
---------------

`mediatools/scripts/fetch-ffmpeg.sh` downloads release assets into
`third_party/ffmpeg/<goos>-<goarch>/ffmpeg-audio`. After a new tag with
libopus encode builds, bump the version pin and re-fetch.

For a local macOS helper without waiting on CI:

```sh
cd ffmpeg-build && STAGE_MEDIATOOLS=1 ./build-macos-local.sh
```
