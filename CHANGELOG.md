# Changelog
All notable changes to this project will be documented in this file.

## [Unreleased]
### Added
- `encode` build variant with audio encoders/muxers, MP3 via static libmp3lame,
  and Opus via static **libopus** (`build-opus.sh`). Selected with
  `FFMPEG_VARIANT=encode`.
- `build-macos-local.sh` for on-Mac encode builds (+ optional
  `STAGE_MEDIATOOLS=1` into ubii `mediatools/third_party`).
- `arm64-linux-gnu` builds.
- CI: Linux + Windows matrix on push/PR/tags (`build.yml`); Windows ARM64
  encode remains in `build-windows-arm64.yml`.

### Changed
- Upgraded FFmpeg to 8.1.2.
- Encode variant no longer enables experimental native `--enable-encoder=opus`
  (scrambled audio); uses `--enable-libopus` / `--enable-encoder=libopus`.
- macOS dropped from default CI matrix (build locally).

## [4.2.2-5] - 2020-02-19
### Changed
- Linux and Windows builds now use the manylinux2010 Docker image defined by the Python community.

### Removed
- Removed i686 and armhf builds.

## [4.2.2-4] - 2020-02-12
### Changed
- Enable PIC in static builds

[Unreleased]: https://github.com/acoustid/ffmpeg-build/compare/v4.2.2-5...HEAD
[4.2.2-5]: https://github.com/acoustid/ffmpeg-build/compare/v4.2.2-4...v4.2.2-5
[4.2.2-4]: https://github.com/acoustid/ffmpeg-build/compare/v4.2.2-3...v4.2.2-4
