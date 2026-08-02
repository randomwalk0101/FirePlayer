# FirePlayer

FirePlayer 是一款面向语言学习的 macOS 轻量音频播放器。

目前支持：

- macOS 12.0 或更高版本
- Intel Mac
- Apple Silicon Mac
- 仅支持音频播放

暂不支持视频播放。

## 下载

如果你使用的是 GitHub Release 版本，请到本仓库的 Releases 页面下载最新的 `.zip` 或 `.dmg` 文件。

如果你使用的是源码包，请下载或克隆仓库后，运行 `build.command` 在本机编译。

## 安装

1. 下载 Release 压缩包或源码包。
2. 解压文件。
3. 双击 `build.command`，开始生成 `FirePlayer.app`。
4. 如果 macOS 弹出权限提示，请允许终端或当前 shell 执行脚本。
5. 构建完成后，打开 `FirePlayer.app`。

如果首次打开时被系统拦截：

1. 按住 Control 键点击 `FirePlayer.app`。
2. 选择“打开”。
3. 在安全提示中确认继续。

## 支持的 Mac

- Intel 机型：生成 `x86_64` 版本。
- Apple Silicon 机型：生成 `arm64` 版本。

源码可以在两类机器上分别本地编译，但生成的 App 架构不同。

## 使用方法

FirePlayer 主要用于语言学习场景的音频播放。

- 从 Finder 打开音频文件，或使用应用内的打开流程。
- 播放时可配合字幕跟读学习。
- 使用播放控制按钮进行暂停、继续和跳转。

## 源码构建

需要环境：

- macOS 12.0 或更高版本
- Xcode Command Line Tools
- `swiftc`、`xcrun`、`sips`、`iconutil`

构建命令：

```bash
cd /path/to/FirePlayer
chmod +x build.command
./build.command
```

脚本会在项目目录下生成本地 `FirePlayer.app`。

## 第一版说明

这个仓库的首个公开版本，重点是稳定的 macOS 音频播放和语言学习体验。当前还不支持视频播放。

## 许可证

如果你希望其他人复用或再分发项目，请在正式发布前补充许可证。
