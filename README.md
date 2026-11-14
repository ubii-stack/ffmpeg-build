Static audio-only FFmpeg builds
===============================

This project contains scripts for small static audio-only FFmpeg builds. The
default builds are used for Chromaprint packaging (`fpcalc`), and there is an
additional variant that can also encode audio.

Building is done using GitHub Actions. You can find the built binaries on the
releases page.

The current FFmpeg version is **8.1.2**. The builds are LGPL-licensed (no
`--enable-gpl` or `--enable-nonfree`).

Variants
--------

Each platform is built in two variants, selected with the `FFMPEG_VARIANT`
environment variable:

  - `decode` (default, output label `audio`) — audio **decoders** only, as
    needed by Chromaprint. This is the small, fully self-contained build.
  - `encode` (output label `audio-encode`) — everything in `decode` plus native
    audio **encoders** and muxers for transcoding, including MP3 via a
    statically linked [LAME](https://lame.sourceforge.io/), built from source by
    `build-lame.sh`.

Supported platforms:

  - Linux
      * `x86_64-linux-gnu`
      * `arm64-linux-gnu`
  - Windows
      * `x86_64-w64-mingw32`
      * `i686-w64-mingw32` (32-bit)
      * `aarch64-w64-mingw32` (Windows on ARM; needs [llvm-mingw](https://github.com/mstorsjo/llvm-mingw), not apt `mingw-w64`)
  - macOS
      * `x86_64-apple-macos10.9` (macOS Mavericks and newer on Intel CPU)
      * `arm64-apple-macos11` (macOS Big Sur and newer on Apple M1 CPU)

CI workflows
------------

  - `.github/workflows/build-windows-arm64.yml` — **active CI**: Windows ARM64
    **audio-encode only** (`ARCH=aarch64`, `FFMPEG_VARIANT=encode`). Installs
    llvm-mingw on Ubuntu. Runs on push to `main`, PRs, tags `v*`, and
    **workflow_dispatch**.
  - `.github/workflows/build.yml` — original full matrix (Linux / Windows x86 /
    macOS). Kept for later; **manual only** (`workflow_dispatch`). Uncomment
    the `push` / `pull_request` / `tags` block in that file to restore automatic
    full builds.

Actions UI:

  - Day-to-day: **Build Windows ARM64 ffmpeg** (auto on push/PR, or Run workflow).
  - Full matrix later: **Build static ffmpeg** → **Run workflow**.

GitHub Releases (Acoustid-style)
--------------------------------

Release **assets** (`.tar.gz` per platform/variant) are uploaded when you push a
version tag matching `v*`, for example:

```sh
git tag v8.1.2-1
git push origin v8.1.2-1
```

Each tarball unpacks to a prefix directory such as
`ffmpeg-8.1.2-audio-encode-aarch64-w64-mingw32/` with `bin/ffmpeg.exe`.

**One-time repo setup (required for releases):**

1. Open **Settings → Actions → General → Workflow permissions**  
   https://github.com/ubii-stack/ffmpeg-build/settings/actions  
2. Choose **Read and write permissions** (not read-only). Save.

Pushes to `main` without a tag only produce workflow **Artifacts** (retention
limited); use a tag when you want files on the **Releases** page.

A Git **tag alone** (failed release job) shows as **“N tags”** on the repo; a
successful run creates a **Release** with downloadable `.tar.gz` assets under
**Releases** (not only under Tags).

Building locally
----------------

The build scripts read the target architecture and variant from environment
variables, for example:

```sh
ARCH=x86_64 FFMPEG_VARIANT=decode ./build-linux.sh
ARCH=x86_64 FFMPEG_VARIANT=encode ./build-linux.sh
TARGET=arm64-apple-macos11 FFMPEG_VARIANT=encode ./build-macos.sh

# Windows ARM64 (after putting llvm-mingw bin/ on PATH):
ARCH=aarch64 FFMPEG_VARIANT=encode ./build-windows.sh
# ARCH=arm64 is accepted as an alias for aarch64 on Windows.
```

The resulting tree is placed under `artifacts/`.