# FirePlayer

[English](README.md) | [简体中文](README_zh-CN.md)

FirePlayer is a desktop audio player for language learning. It focuses on large synchronized subtitles, quick sentence navigation, and playlist workflows for listening practice.

The repository now contains two implementations:

- `FirePlayer.swift`: native macOS AppKit version.
- `cross-platform/`: Electron version for Windows, Ubuntu/Linux, and macOS.

FirePlayer plays audio files only. It does not play video files.

## Current Status

## Download

Download the latest release from:

[FirePlayer v1.7.2 Releases](https://github.com/randomwalk0101/FirePlayer/releases/tag/v1.7.2)

Release files:

- macOS Apple Silicon: `FirePlayer-v1.7.2-macOS-arm64.zip`
- macOS Intel: `FirePlayer-v1.7.2-macOS-x86_64.zip`
- Windows x64 installer: `FirePlayer-v1.7.2-Windows-x64-Setup.exe`
- Windows x64 portable: `FirePlayer-v1.7.2-Windows-x64-Portable.exe`
- Ubuntu x64 AppImage: `FirePlayer-v1.7.2-Ubuntu-x64.AppImage`
- Ubuntu x64 deb: `FirePlayer-v1.7.2-Ubuntu-x64.deb`

### macOS Native Version

The macOS version is the most complete version today.

Recent improvements:

- Playlist supports multi-select.
- Right-click playlist deletion can remove one or many selected items.
- Single-clicking the subtitle area toggles play/pause.
- Double-clicking the subtitle area enters or exits full screen.
- Keyboard shortcuts are available for play/pause, full screen, sentence navigation, and track navigation.
- Subtitle file selector supports multiple matching `.srt` variants for the current audio.
- Subtitle display modes include English, bilingual, stress skeleton, speech-flow annotation, and pronunciation hints.
- Playback modes include sequential playback, repeat one, and repeat all.
- Font size, subtitle color, speed, volume, previous/next sentence, and previous/next track controls are available.

Build:

```bash
chmod +x build.command
./build.command
```

The script creates `FirePlayer.app` in the repository folder.

Requirements:

- macOS 12.0 or later
- Xcode Command Line Tools
- `swiftc`, `xcrun`, `sips`, and `iconutil`

Architecture note:

- Download `macOS-arm64` for Apple Silicon Macs.
- Download `macOS-x86_64` for Intel Macs.
- Local builds default to the current Mac architecture.
- To build a specific architecture locally, set `FIREPLAYER_TARGET_ARCH=arm64` or `FIREPLAYER_TARGET_ARCH=x86_64`.

### Windows Version

The Windows version lives in `cross-platform/` and uses Electron.

Implemented:

- Add audio files.
- Add folders and import audio files from them.
- Match nearby `.srt` subtitle files by audio filename.
- Switch subtitle variants.
- Playlist multi-select with `Ctrl` or `Shift`.
- Right-click deletion for one or many selected playlist items.
- Single-click subtitle area to play/pause.
- Double-click subtitle area to enter/exit full screen.
- Adjustable subtitle size with `A-` and `A+`.
- Subtitle size is applied through both CSS variables and direct inline styles so it updates reliably on Windows.
- Keyboard shortcuts match the macOS version.
- Subtitle color, volume, speed, previous/next track, previous/next sentence, and playback mode controls.

Build on Windows:

```bash
cd cross-platform
npm install
npm run build:win
```

Output is written to `cross-platform/dist/`.

### Ubuntu / Linux Version

The Ubuntu version also lives in `cross-platform/` and uses the same Electron codebase.

Implemented:

- Same core playback, subtitle, playlist, right-click deletion, click-to-play, double-click-fullscreen, and font-size controls as the Windows version.
- Same keyboard shortcuts as the macOS and Windows versions.
- Linux packaging targets are configured for AppImage and Debian package output.
- Subtitle size is applied through both CSS variables and direct inline styles so it updates reliably on Ubuntu/Linux desktop environments.

Build on Ubuntu:

```bash
cd cross-platform
npm install
npm run build:linux
```

Output is written to `cross-platform/dist/`.

## Cross-Platform Development

## Keyboard Shortcuts

- `Space`: play / pause
- `F`: enter / exit full screen
- `Esc`: exit full screen
- `Left Arrow`: previous sentence
- `Right Arrow`: next sentence
- `Ctrl`/`Cmd` + `Left Arrow`: previous track
- `Ctrl`/`Cmd` + `Right Arrow`: next track

The same shortcuts are implemented in the native macOS version and the Electron Windows/Ubuntu version.

Run the Electron app locally:

```bash
cd cross-platform
npm install
npm start
```

Available scripts:

```bash
npm run pack
npm run build:win
npm run build:linux
npm run build:mac
```

Recommended packaging practice:

- Build the Windows installer on Windows.
- Build Ubuntu/Linux packages on Ubuntu.
- Build macOS packages on macOS.

Electron can cross-build some targets, but native packaging is more reliable and avoids missing platform tools such as Wine or Linux package dependencies.

## Subtitle Naming

FirePlayer automatically matches subtitles near the audio file. Supported naming examples:

```text
lesson01.mp3
lesson01.srt
lesson01.en.srt
lesson01.bi.srt
lesson01.zh.srt
lesson01.stress.en.srt
lesson01.flow.en.srt
lesson01.phonetic.en.srt
```

## License

Released under the [MIT License](LICENSE).
