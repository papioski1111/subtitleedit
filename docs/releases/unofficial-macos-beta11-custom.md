# Unofficial macOS Beta11 Custom Build

This is an unofficial macOS build based on Subtitle Edit `v5.0.0-beta11`.

It is intended for users who want the macOS beta build plus the fixes listed below.
It is not an official release from the Subtitle Edit maintainer.

## What changed

- Fixed overlap highlighting so `Show` and `Hide` are colored only on actual overlaps.
- Kept `Duration` highlighting for duration-limit issues only.
- Fixed `Synchronization -> Adjust all times` time input editing issues.
- Fixed `Backspace` and `Delete` behavior in the time input control.
- Fixed `Batch convert -> Offset time codes` so the offset is actually applied.
- Fixed `Batch convert -> Offset time codes` so it does not remove line breaks unless `Remove line breaks` is explicitly enabled.
- Added ASS/SSA `Style` column support in the subtitle grid.
- Hid the `Actor` column when no actor values exist in the loaded subtitle.
- Disabled automatic `Layer` column display for this flow.
- Added separate macOS app data storage for `Subtitle Edit Beta11.app` so it does not share settings/history with the regular Subtitle Edit app.
- Added a macOS packaging script for building a separate beta app bundle.

## Notes

- This build is unsigned and unofficial.
- On macOS, it should be installed in `/Applications`.
- If macOS blocks the app, remove quarantine and apply ad-hoc signing:

```bash
sudo xattr -rd com.apple.quarantine "/Applications/Subtitle Edit Beta11.app"
sudo codesign --force --deep --sign - "/Applications/Subtitle Edit Beta11.app"
```

## Attribution

- Upstream project: Subtitle Edit
- Upstream repository: https://github.com/SubtitleEdit/subtitleedit
- License: MIT

## Scope

This release is meant as a community/custom build for macOS users who want these fixes before they appear in an official release.
