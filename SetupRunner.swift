import Foundation
import AppKit

enum StepState {
    case idle, running, success, failure, skipped
}

struct Step: Identifiable {
    let id = UUID()
    let title: String
    var state: StepState = .idle
    var detail: String = ""
}

@MainActor
class SetupRunner: ObservableObject {
    @Published var steps: [Step] = [
        Step(title: "关闭 Mac 端 LocalSend"),
        Step(title: "清理端口 53317 占用"),
        Step(title: "确认端口已空闲"),
        Step(title: "检查 adb"),
        Step(title: "检查 Android 设备连接"),
        Step(title: "重启 adb / 清理旧 reverse"),
        Step(title: "建立 adb reverse TCP 转发"),
        Step(title: "启动 Mac 端 LocalSend"),
    ]
    @Published var phase: Phase = .ready
    @Published var errorMessage: String = ""
    @Published var reverseList: String = ""

    enum Phase {
        case ready, confirming, running, done, failed
    }

    private let port = 53317
    private var adbPath: String = ""

    func start() { phase = .confirming }

    func proceedAfterConfirm() {
        phase = .running
        Task { await runAll() }
    }

    private func runAll() async {
        await run(index: 0) {
            _ = try? await self.runAppleScript("tell application \"LocalSend\" to quit")
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            return (true, "已发送退出指令")
        }

        // lsof exits 1 when no process found — use shellIgnoringExitCode
        await run(index: 1) {
            let result = await self.shellIgnoringExitCode("/usr/sbin/lsof -ti tcp:\(self.port)")
            let pids = result.trimmingCharacters(in: .whitespacesAndNewlines)
            if pids.isEmpty { return (true, "端口未被占用") }
            for pid in pids.split(separator: "\n") {
                _ = await self.shellIgnoringExitCode("kill -9 \(pid)")
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            return (true, "已终止占用进程：\(pids.replacingOccurrences(of: "\n", with: ", "))")
        }

        await run(index: 2) {
            let result = await self.shellIgnoringExitCode("/usr/sbin/lsof -i tcp:\(self.port)")
            if result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return (true, "端口 \(self.port) 已空闲")
            }
            throw RunnerError.message("""
            Mac 上端口 \(self.port) 仍被占用。
            请手动执行下面命令检查：
            lsof -nP -iTCP:\(self.port)
            """)
        }

        await run(index: 3) {
            let which = await self.shellIgnoringExitCode("which adb")
            let candidates = ["/usr/local/bin/adb", "/opt/homebrew/bin/adb",
                              which.trimmingCharacters(in: .whitespacesAndNewlines)]
            for p in candidates where !p.isEmpty && FileManager.default.fileExists(atPath: p) {
                self.adbPath = p
                return (true, p)
            }
            throw RunnerError.message("""
            找不到 adb。
            请先确认 adb 已安装，并且终端执行 which adb 能找到。
            例如可以先安装：
            brew install android-platform-tools
            """)
        }

        await run(index: 4) {
            let result = await self.shellIgnoringExitCode("\(self.adbPath) get-state")
            let state = result.trimmingCharacters(in: .whitespacesAndNewlines)
            if state == "device" { return (true, "设备已连接") }
            throw RunnerError.message("""
            未检测到 Android 设备（状态：\(state.isEmpty ? "无响应" : state)）。
            请检查：
            1. USB 线是否连接正常
            2. 手机是否已开启 USB 调试
            3. 手机上是否点了“允许此电脑调试”
            4. 终端执行 adb devices 是否能看到设备
            """)
        }

        await run(index: 5) {
            _ = await self.shellIgnoringExitCode("\(self.adbPath) kill-server")
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            _ = await self.shellIgnoringExitCode("\(self.adbPath) start-server")
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            _ = await self.shellIgnoringExitCode("\(self.adbPath) reverse --remove-all")
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            return (true, "adb 已重启")
        }

        await run(index: 6) {
            do {
                _ = try await self.shell("\(self.adbPath) reverse tcp:\(self.port) tcp:\(self.port)")
            } catch {
                throw RunnerError.message("""
                adb reverse 建立失败。
                大概率是 Android 端 LocalSend 还没真正关掉，或者 USB/ADB 状态不稳定。
                可以先手动确认 Android 端 LocalSend 已关闭，再重新运行本工具。

                原始错误：
                \(error.localizedDescription)
                """)
            }
            let list = await self.shellIgnoringExitCode("\(self.adbPath) reverse --list")
            self.reverseList = list.trimmingCharacters(in: .whitespacesAndNewlines)
            return (true, "tcp:\(self.port) ⇄ tcp:\(self.port)")
        }

        await run(index: 7) {
            do {
                _ = try await self.shell("open -a LocalSend")
            } catch {
                throw RunnerError.message("""
                无法打开 Mac 端 LocalSend。
                请确认 App 名称确实是：LocalSend

                原始错误：
                \(error.localizedDescription)
                """)
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            return (true, "LocalSend 已启动")
        }

        if steps.allSatisfy({ $0.state == .success }) {
            phase = .done
            await sendNotification()
        }
    }

    private func run(index: Int, block: @escaping () async throws -> (Bool, String)) async {
        guard phase != .failed else { return }
        steps[index].state = .running
        do {
            let (_, detail) = try await block()
            steps[index].state = .success
            steps[index].detail = detail
        } catch {
            steps[index].state = .failure
            steps[index].detail = error.localizedDescription
            errorMessage = error.localizedDescription
            phase = .failed
        }
    }

    /// Throws on non-zero exit. Use for commands that must succeed (adb reverse, open).
    private func shell(_ command: String) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let proc = Process()
            let outPipe = Pipe(), errPipe = Pipe()
            proc.executableURL = URL(fileURLWithPath: "/bin/bash")
            proc.arguments = ["-c", command]
            proc.standardOutput = outPipe
            proc.standardError = errPipe
            try proc.run()
            proc.waitUntilExit()
            let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            if proc.terminationStatus != 0 {
                let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let msg = err.trimmingCharacters(in: .whitespacesAndNewlines)
                throw RunnerError.message(msg.isEmpty ? "命令退出码 \(proc.terminationStatus)" : msg)
            }
            return out
        }.value
    }

    /// Never throws. Use for lsof / which / adb commands that exit non-zero on empty results.
    private func shellIgnoringExitCode(_ command: String) async -> String {
        await Task.detached(priority: .userInitiated) {
            let proc = Process()
            let outPipe = Pipe()
            proc.executableURL = URL(fileURLWithPath: "/bin/bash")
            proc.arguments = ["-c", command]
            proc.standardOutput = outPipe
            proc.standardError = Pipe()
            try? proc.run()
            proc.waitUntilExit()
            return String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        }.value
    }

    private func runAppleScript(_ script: String) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            var err: NSDictionary?
            let result = NSAppleScript(source: script)?.executeAndReturnError(&err)
            if let e = err { throw RunnerError.message(e.description) }
            return result?.stringValue ?? ""
        }.value
    }

    private func sendNotification() async {
        _ = try? await runAppleScript("""
        display notification "Reverse 已建立。现在请手动打开 Android 端 LocalSend。" with title "LocalSend USB"
        """)
    }

    func reset() {
        for i in steps.indices { steps[i].state = .idle; steps[i].detail = "" }
        phase = .ready; errorMessage = ""; reverseList = ""; adbPath = ""
    }
}

enum RunnerError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        if case .message(let m) = self { return m }
        return nil
    }
}
