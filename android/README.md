# FirePlayer Android

[English](README.md) | [简体中文](../README_zh-CN.md)

This is the touch-first Android version of FirePlayer.

It is designed for:

- Android phones
- Android tablets
- Ordinary Android head units that allow APK installation

It is not an Android Auto projection app and is not guaranteed to run on locked-down car systems.

## Features

- Touch-first landscape interface.
- Add local audio files with the Android system file picker.
- Add local `.srt` subtitle files with the Android system file picker.
- Match subtitles by filename stem, such as `lesson01.mp3` and `lesson01.srt`.
- Large English and bilingual subtitle display.
- Tap subtitle area to play or pause.
- Previous/next sentence.
- Previous/next track.
- Adjustable subtitle font size.
- Playback speed presets.
- Playlist panel that can be hidden for a larger subtitle area.

## Build

```bash
cd android
gradle :app:assembleDebug
```

The APK is written to:

```text
android/app/build/outputs/apk/debug/app-debug.apk
```

GitHub Actions builds and publishes the APK automatically for tagged releases.
