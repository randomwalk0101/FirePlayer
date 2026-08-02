FirePlayer 1.6.10

适用系统：macOS 12.0 或更高版本。
已知适用：Intel MacBook Pro（macOS 12.7.6）与 Apple Silicon Mac。

使用方法：
1. 解压 ZIP。
2. 双击 build.command。
3. 脚本会自动识别当前电脑：
   - Intel Mac：编译 x86_64 版本。
   - M1/M2/M3/M4 Mac：编译 arm64 版本。
4. 构建完成后，同一文件夹内会生成 FirePlayer.app。
5. 首次打开如被系统拦截，请右键 FirePlayer.app → 打开。

说明：
- 同一份源码可在两类 Mac 上分别本地编译。
- 在 Intel Mac 上编译出的 App 可用于 Intel Mac。
- 在 M 芯片 Mac 上编译出的 App 可用于 M 芯片 Mac。
- 最低系统版本固定为 macOS 12.0，因此 macOS 12.7.6 可以运行。

FirePlayer 1.6.10 新增：
- 播放时连续 3 秒没有鼠标或键盘操作，底部进度条与全部控制按钮自动淡出隐藏。
- 移动鼠标、单击、滚动或按任意键时，控制区立即恢复显示。
- 暂停播放时控制区保持显示。
- 控制区隐藏后，字幕区域自动扩展到窗口底部。

FirePlayer 1.6.11：修复 viewDidAppear 重复定义导致的编译失败。
