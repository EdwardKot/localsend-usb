import Foundation

enum AppText {
    static var usesChinese: Bool {
        let preferred = Locale.preferredLanguages.first?.lowercased()
        let current = Locale.current.identifier.lowercased()
        return (preferred ?? current).hasPrefix("zh")
    }

    static func choose(_ chinese: String, _ english: String) -> String {
        usesChinese ? chinese : english
    }

    static var subtitle: String { choose("adb reverse 转发工具", "adb reverse helper") }
    static var reverseListTitle: String { choose("当前 reverse 列表", "Current reverse list") }
    static var nextStepsTitle: String { choose("下一步请手动操作：", "Next steps:") }
    static var nextStepsBody: String {
        choose(
            "1. 打开 Android 端 LocalSend\n2. 保持 USB 连接\n3. 开始传图",
            "1. Open LocalSend on Android\n2. Keep the USB cable connected\n3. Start transferring photos"
        )
    }

    static var statusReady: String { choose("准备就绪", "Ready") }
    static var statusWaitingConfirm: String { choose("等待确认", "Waiting for confirmation") }
    static var statusRunning: String { choose("运行中…", "Running…") }
    static var statusDone: String {
        choose("完成，可以继续传图或关闭本工具", "Done. You can transfer now or quit this tool")
    }
    static var statusFailed: String { choose("失败", "Failed") }

    static var rerun: String { choose("重新运行", "Run Again") }
    static var quit: String { choose("退出", "Quit") }
    static var retry: String { choose("重试", "Retry") }
    static var start: String { choose("开始", "Start") }
    static var cancel: String { choose("取消", "Cancel") }
    static var continueConfirmed: String { choose("已确认，继续", "Confirmed, Continue") }

    static var confirmTitle: String { choose("开始前请确认", "Before You Start") }
    static var confirmAndroidClosed: String {
        choose("已手动关闭 Android 端 LocalSend", "Android LocalSend has been closed manually")
    }
    static var confirmEncryptionOff: String {
        choose("两端的\"加密\"选项均已关闭", "Encryption is disabled on both devices")
    }
    static var confirmUSBReady: String {
        choose("USB 已连接，USB 调试已开启", "USB is connected and USB debugging is enabled")
    }

    static var stepCloseMacLocalSend: String { choose("关闭 Mac 端 LocalSend", "Close LocalSend on Mac") }
    static var stepClearPort: String { choose("清理端口 53317 占用", "Clear port 53317 usage") }
    static var stepConfirmPortFree: String { choose("确认端口已空闲", "Confirm the port is free") }
    static var stepCheckAdb: String { choose("检查 adb", "Check adb") }
    static var stepCheckDevice: String { choose("检查 Android 设备连接", "Check Android device connection") }
    static var stepRestartAdb: String { choose("重启 adb / 清理旧 reverse", "Restart adb / clear old reverse rules") }
    static var stepEstablishReverse: String {
        choose("建立 adb reverse TCP 转发", "Create adb reverse TCP forwarding")
    }
    static var stepLaunchLocalSend: String { choose("启动 Mac 端 LocalSend", "Launch LocalSend on Mac") }

    static var sentQuitSignal: String { choose("已发送退出指令", "Quit signal sent") }
    static var portUnused: String { choose("端口未被占用", "The port is not in use") }
    static func killedProcesses(_ pids: String) -> String {
        choose("已终止占用进程：\(pids)", "Stopped processes using the port: \(pids)")
    }
    static func portFree(_ port: Int) -> String {
        choose("端口 \(port) 已空闲", "Port \(port) is now free")
    }
    static func portStillOccupied(_ port: Int) -> String {
        choose(
            """
            Mac 上端口 \(port) 仍被占用。
            请手动执行下面命令检查：
            lsof -nP -iTCP:\(port)
            """,
            """
            Port \(port) is still in use on this Mac.
            Run this command to inspect it:
            lsof -nP -iTCP:\(port)
            """
        )
    }

    static var adbNotFound: String {
        choose(
            """
            找不到 adb。
            请先确认 adb 已安装，并且终端执行 which adb 能找到。
            例如可以先安装：
            brew install android-platform-tools
            """,
            """
            adb was not found.
            Make sure adb is installed and `which adb` can find it.
            For example, install it with:
            brew install android-platform-tools
            """
        )
    }

    static var deviceConnected: String { choose("设备已连接", "Device connected") }
    static func deviceNotDetected(_ state: String) -> String {
        choose(
            """
            未检测到 Android 设备（状态：\(state)）。
            请检查：
            1. USB 线是否连接正常
            2. 手机是否已开启 USB 调试
            3. 手机上是否点了“允许此电脑调试”
            4. 终端执行 adb devices 是否能看到设备
            """,
            """
            No Android device was detected (state: \(state)).
            Check:
            1. The USB cable connection
            2. USB debugging is enabled on the phone
            3. You approved “Allow USB debugging” on the phone
            4. `adb devices` can see the device
            """
        )
    }

    static var adbRestarted: String { choose("adb 已重启", "adb restarted") }
    static func reverseEstablished(_ port: Int) -> String {
        choose("tcp:\(port) ⇄ tcp:\(port)", "tcp:\(port) ⇄ tcp:\(port)")
    }
    static func reverseFailed(_ error: String) -> String {
        choose(
            """
            adb reverse 建立失败。
            大概率是 Android 端 LocalSend 还没真正关掉，或者 USB/ADB 状态不稳定。
            可以先手动确认 Android 端 LocalSend 已关闭，再重新运行本工具。

            原始错误：
            \(error)
            """,
            """
            Failed to create adb reverse.
            Most likely LocalSend is not fully closed on Android yet, or the USB/ADB connection is unstable.
            Make sure LocalSend is closed on Android, then run this tool again.

            Original error:
            \(error)
            """
        )
    }

    static var localSendLaunched: String { choose("LocalSend 已启动", "LocalSend launched") }
    static func openLocalSendFailed(_ error: String) -> String {
        choose(
            """
            无法打开 Mac 端 LocalSend。
            请确认 App 名称确实是：LocalSend

            原始错误：
            \(error)
            """,
            """
            Failed to open LocalSend on Mac.
            Make sure the app name is exactly: LocalSend

            Original error:
            \(error)
            """
        )
    }

    static func commandExitCode(_ code: Int32) -> String {
        choose("命令退出码 \(code)", "Command exited with code \(code)")
    }

    static var noResponse: String { choose("无响应", "No response") }
    static var notificationBody: String {
        choose("Reverse 已建立。现在请手动打开 Android 端 LocalSend。", "Reverse is ready. Now open LocalSend on Android manually.")
    }
}
