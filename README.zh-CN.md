# LocalSend USB

一个 macOS SwiftUI 小工具，用来快速重建 `adb reverse`，并启动 Mac 端 LocalSend，方便通过 USB 连接 Android 设备进行传图。

## 适用场景

这个工具适合下面这种使用方式：

- Mac 上已经安装了 LocalSend
- Android 手机通过 USB 连接到 Mac
- 手机已开启 USB 调试
- Mac 上已经安装 `adb`
- 希望减少每次手动执行 `adb reverse` 和重启 LocalSend 的步骤

## 依赖要求

- macOS 14 或更高版本
- 已安装 LocalSend
- 已安装 `adb`，并且终端执行 `which adb` 能找到
- Android 设备已开启 USB 调试

如果还没有安装 `adb`，可以先执行：

```bash
brew install android-platform-tools
```

## 构建方法

在仓库根目录执行：

```bash
./build_app.sh
```

构建完成后，应用会输出到：

```bash
dist/LocalSend USB.app
```

## 使用步骤

1. 用 USB 将 Android 手机连接到 Mac。
2. 确保手机已经开启 USB 调试，并在手机上允许当前电脑的调试授权。
3. 确保 Mac 和 Android 两端都已经安装 LocalSend。
4. 打开 `LocalSend USB.app`。
5. 在确认弹窗里，先手动关闭 Android 端 LocalSend，再点击继续。
6. 工具会自动：
   - 关闭 Mac 端 LocalSend
   - 清理 Mac 上 `53317` 端口占用
   - 检查 `adb`
   - 检查 Android 设备连接状态
   - 重启 `adb` 并清理旧的 `reverse`
   - 建立 `tcp:53317 -> tcp:53317` 的 `adb reverse`
   - 重新打开 Mac 端 LocalSend
7. 工具显示完成后，再手动打开 Android 端 LocalSend。
8. 保持 USB 连接，开始传图。

## 给朋友使用时需要注意

- 这个仓库里的版本不内置 `platform-tools`，所以朋友的 Mac 上也需要先安装 `adb`。
- 第一次打开 app 时，如果 macOS 拦截，可以尝试右键应用后选择“打开”。
- 如果 Mac 端没有安装 LocalSend，最后一步启动 LocalSend 会失败。

## 常见问题

### 1. 提示找不到 `adb`

先在终端执行：

```bash
which adb
```

如果没有输出，先安装：

```bash
brew install android-platform-tools
```

### 2. 提示没有检测到 Android 设备

检查以下几点：

- USB 线是否正常
- 手机是否已开启 USB 调试
- 手机上是否已经点了“允许此电脑调试”
- 终端执行 `adb devices` 时是否能看到设备

### 3. `adb reverse` 建立失败

通常是下面几种情况：

- Android 端 LocalSend 还没有真正关闭
- USB 连接不稳定
- 当前 `adb` 状态异常

这时可以先确认 Android 端 LocalSend 已关闭，再重新运行工具。

## 仓库内容

- `origin-command/localsend-usb.command`：最初的 shell 脚本版本
- `LocalSendUSBApp.swift`、`ContentView.swift`、`SetupRunner.swift`：SwiftUI 应用源码
- `resources/Info.plist`：应用 bundle 元数据
- `scripts/GenerateIcon.swift`：构建时使用的图标生成脚本
