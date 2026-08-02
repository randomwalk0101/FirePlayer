# FirePlayer

FirePlayer is a lightweight macOS audio player for language learning.

It currently supports:

- macOS 12.0 or later
- Intel Macs
- Apple Silicon Macs
- Audio playback only

It does not play video files.

## Download

If you are using a packaged release, download the latest `.zip` or `.dmg` from the GitHub Releases page for this repository.

If you are using the source package, download or clone the repository, then build the app locally with `build.command`.

## Install

1. Download the release archive or source package.
2. Unzip the file.
3. Double-click `build.command` to build `FirePlayer.app`.
4. When macOS asks for permission, allow Terminal or your shell to run the script.
5. After the build finishes, open `FirePlayer.app`.

If macOS blocks the first launch:

1. Control-click `FirePlayer.app`.
2. Choose `Open`.
3. Confirm the security prompt.

## Supported Macs

- Intel-based Macs: builds an `x86_64` app.
- Apple Silicon Macs: builds an `arm64` app.

The same source can be built on either machine type, but the resulting app is architecture-specific.

## Usage

FirePlayer is designed for language study with audio files.

- Open an audio file from Finder, or use the app's open flow if available.
- Use subtitles if you want to follow along while listening.
- Use the playback controls to pause, resume, and seek.

## Build From Source

Requirements:

- macOS 12.0 or later
- Xcode Command Line Tools
- `swiftc`, `xcrun`, `sips`, and `iconutil`

Build steps:

```bash
cd /path/to/FirePlayer
chmod +x build.command
./build.command
```

The script builds a local `FirePlayer.app` in the project folder.

## Release Notes

This repository's first public release is focused on stable macOS audio playback for language learning. Video playback is not supported yet.

## License

Add a license before publishing if you want others to reuse or redistribute the project.
