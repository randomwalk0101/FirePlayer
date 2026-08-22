# FirePlayer Cross Platform

[English](README.md) | [简体中文](../README_zh-CN.md)

This Electron version is intended for Windows, Ubuntu, and macOS.

## Run

```bash
npm install
npm start
```

## Build

```bash
npm run build:win
npm run build:linux
npm run build:mac
```

Recommended final packaging is to run `build:win` on Windows and `build:linux` on Ubuntu. Cross-building from macOS can work for some targets, but Windows installers often need extra tooling such as Wine, and Linux packages are most reliable on Linux.

## Implemented Features

- Add one or more audio files.
- Add a folder and automatically load audio files from it.
- Match nearby `.srt` subtitle files by audio filename.
- Switch subtitle versions.
- Playlist multi-select with Ctrl/Command or Shift.
- Right-click playlist deletion for one or many selected items.
- Click subtitle area to play or pause.
- Double-click subtitle area to enter or exit full screen.
- Adjustable subtitle font size with `A-` and `A+`.
- Subtitle size is applied both through CSS variables and direct inline styles so it updates reliably on Windows and Ubuntu.
- Subtitle color, volume, speed, previous/next track, previous/next sentence, sequential/repeat-one/repeat-all playback.
