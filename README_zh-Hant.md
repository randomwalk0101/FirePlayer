# FirePlayer

FirePlayer 是一款面向語言學習的 macOS 輕量音訊播放器。

目前支援：

- macOS 12.0 或以上版本
- Intel Mac
- Apple Silicon Mac
- 僅支援音訊播放

暫不支援影片播放。

## 下載

第一版 macOS 下載地址：

[FirePlayer-v1.6.11-macOS.zip](https://github.com/randomwalk0101/FirePlayer/releases/download/v1.6.11/FirePlayer-v1.6.11-macOS.zip)

你也可以打開 [GitHub Releases 頁面](https://github.com/randomwalk0101/FirePlayer/releases)，下載最新的 macOS 安裝包。

如果你使用的是原始碼包，請下載或複製倉庫後，執行 `build.command` 在本機編譯。

## 安裝

1. 下載 Release 壓縮包或原始碼包。
2. 解壓檔案。
3. 雙擊 `build.command`，開始產生 `FirePlayer.app`。
4. 如果 macOS 顯示權限提示，請允許終端機或目前 shell 執行腳本。
5. 完成後，打開 `FirePlayer.app`。

如果首次開啟時被系統攔截：

1. 按住 Control 鍵點擊 `FirePlayer.app`。
2. 選擇「打開」。
3. 在安全性提示中確認繼續。

## 支援的 Mac

- Intel 機型：產生 `x86_64` 版本。
- Apple Silicon 機型：產生 `arm64` 版本。

原始碼可在兩類機器上分別本機編譯，但產生的 App 架構不同。

## 使用方法

FirePlayer 主要用於語言學習場景的音訊播放。

- 從 Finder 開啟音訊檔案，或使用應用程式內的開啟流程。
- 播放時可搭配字幕跟讀學習。
- 使用播放控制按鈕進行暫停、繼續與跳轉。

## 原始碼建置

需要環境：

- macOS 12.0 或以上版本
- Xcode Command Line Tools
- `swiftc`、`xcrun`、`sips`、`iconutil`

建置命令：

```bash
cd /path/to/FirePlayer
chmod +x build.command
./build.command
```

腳本會在專案目錄下產生本機 `FirePlayer.app`。

## 第一版說明

這個倉庫的首個公開版本，重點是穩定的 macOS 音訊播放與語言學習體驗。目前仍不支援影片播放。

## 授權

本專案基於 [MIT License](LICENSE) 發布。
