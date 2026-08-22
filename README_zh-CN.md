# FirePlayer

[English](README.md) | [简体中文](README_zh-CN.md)

FirePlayer 是一款面向语言学习的桌面音频播放器，重点是大字幕、句子跳转、字幕跟读和播放清单管理。

仓库现在包含两个版本：

- `FirePlayer.swift`：macOS 原生 AppKit 版本。
- `cross-platform/`：基于 Electron 的 Windows、Ubuntu/Linux、macOS 跨平台版本。

FirePlayer 只播放音频，不播放视频。

## 当前状态

## 下载

请从最新 Release 下载：

[FirePlayer v1.7.0 Releases](https://github.com/randomwalk0101/FirePlayer/releases/tag/v1.7.0)

Release 文件：

- macOS Apple Silicon：`FirePlayer-v1.7.0-macOS-arm64.zip`
- Windows x64 安装版：`FirePlayer-v1.7.0-Windows-x64-Setup.exe`
- Windows x64 便携版：`FirePlayer-v1.7.0-Windows-x64-Portable.exe`
- Ubuntu x64 AppImage：`FirePlayer-v1.7.0-Ubuntu-x64.AppImage`
- Ubuntu x64 deb：`FirePlayer-v1.7.0-Ubuntu-x64.deb`

### macOS 原生版

macOS 原生版是目前功能最完整的版本。

近期完善内容：

- 播放清单支持多选。
- 播放清单可右键删除一个或多个已选项目。
- 单击字幕区域可播放/暂停。
- 双击字幕区域可进入/退出全屏。
- 支持为当前音频切换不同 `.srt` 字幕版本。
- 字幕显示模式包括英文、双语、重音骨架、语流标注、发音提示。
- 播放模式包括顺序播放、单曲循环、列表循环。
- 支持字号、字幕颜色、播放速度、音量、上一句/下一句、上一首/下一首。

构建命令：

```bash
chmod +x build.command
./build.command
```

脚本会在仓库目录下生成 `FirePlayer.app`。

环境要求：

- macOS 12.0 或更高版本
- Xcode Command Line Tools
- `swiftc`、`xcrun`、`sips`、`iconutil`

架构说明：

- 在 Apple Silicon 上构建会生成 `arm64` 应用。
- 在 Intel Mac 上构建会生成 `x86_64` 应用。

### Windows 版

Windows 版位于 `cross-platform/`，使用 Electron 实现。

已实现：

- 添加一个或多个音频文件。
- 添加文件夹并自动导入其中的音频。
- 按音频文件名自动匹配附近的 `.srt` 字幕。
- 切换字幕版本。
- 播放清单支持 `Ctrl` 或 `Shift` 多选。
- 右键删除一个或多个已选清单项目。
- 单击字幕区域播放/暂停。
- 双击字幕区域进入/退出全屏。
- `A-` / `A+` 调整字幕字号。
- 字幕字号同时通过 CSS 变量和内联样式应用，专门避免 Windows 上字号不刷新或不生效的问题。
- 支持字幕颜色、音量、速度、上一首/下一首、上一句/下一句、播放模式。

在 Windows 上构建：

```bash
cd cross-platform
npm install
npm run build:win
```

产物会输出到 `cross-platform/dist/`。

### Ubuntu / Linux 版

Ubuntu/Linux 版同样位于 `cross-platform/`，与 Windows 版共用 Electron 代码。

已实现：

- 与 Windows 版相同的核心播放、字幕、清单、右键删除、点击播放、双击全屏和字号调整能力。
- 已配置 AppImage 和 Debian 包构建目标。
- 字幕字号同样通过 CSS 变量和内联样式双路径应用，保证在 Ubuntu/Linux 桌面环境中可靠刷新。

在 Ubuntu 上构建：

```bash
cd cross-platform
npm install
npm run build:linux
```

产物会输出到 `cross-platform/dist/`。

## 跨平台版本地运行

```bash
cd cross-platform
npm install
npm start
```

可用脚本：

```bash
npm run pack
npm run build:win
npm run build:linux
npm run build:mac
```

推荐打包方式：

- Windows 安装包建议在 Windows 电脑上构建。
- Ubuntu/Linux 包建议在 Ubuntu 电脑上构建。
- macOS 包建议在 macOS 电脑上构建。

Electron 可以跨平台构建部分目标，但对应系统原生打包更稳定，也能避免缺少 Wine 或 Linux 打包依赖的问题。

## 字幕命名

FirePlayer 会自动匹配音频文件附近的字幕文件。例如：

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

## 许可证

本项目基于 [MIT License](LICENSE) 发布。
