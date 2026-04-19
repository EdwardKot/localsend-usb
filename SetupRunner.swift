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
        Step(title: AppText.stepCloseMacLocalSend),
        Step(title: AppText.stepClearPort),
        Step(title: AppText.stepConfirmPortFree),
        Step(title: AppText.stepCheckAdb),
        Step(title: AppText.stepCheckDevice),
        Step(title: AppText.stepRestartAdb),
        Step(title: AppText.stepEstablishReverse),
        Step(title: AppText.stepLaunchLocalSend),
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
            return (true, AppText.sentQuitSignal)
        }

        // lsof exits 1 when no process found — use shellIgnoringExitCode
        await run(index: 1) {
            let result = await self.shellIgnoringExitCode("/usr/sbin/lsof -ti tcp:\(self.port)")
            let pids = result.trimmingCharacters(in: .whitespacesAndNewlines)
            if pids.isEmpty { return (true, AppText.portUnused) }
            for pid in pids.split(separator: "\n") {
                _ = await self.shellIgnoringExitCode("kill -9 \(pid)")
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            return (true, AppText.killedProcesses(pids.replacingOccurrences(of: "\n", with: ", ")))
        }

        await run(index: 2) {
            let result = await self.shellIgnoringExitCode("/usr/sbin/lsof -i tcp:\(self.port)")
            if result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return (true, AppText.portFree(self.port))
            }
            throw RunnerError.message(AppText.portStillOccupied(self.port))
        }

        await run(index: 3) {
            let which = await self.shellIgnoringExitCode("which adb")
            let candidates = ["/usr/local/bin/adb", "/opt/homebrew/bin/adb",
                              which.trimmingCharacters(in: .whitespacesAndNewlines)]
            for p in candidates where !p.isEmpty && FileManager.default.fileExists(atPath: p) {
                self.adbPath = p
                return (true, p)
            }
            throw RunnerError.message(AppText.adbNotFound)
        }

        await run(index: 4) {
            let result = await self.shellIgnoringExitCode("\(self.adbPath) get-state")
            let state = result.trimmingCharacters(in: .whitespacesAndNewlines)
            if state == "device" { return (true, AppText.deviceConnected) }
            throw RunnerError.message(AppText.deviceNotDetected(state.isEmpty ? AppText.noResponse : state))
        }

        await run(index: 5) {
            _ = await self.shellIgnoringExitCode("\(self.adbPath) kill-server")
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            _ = await self.shellIgnoringExitCode("\(self.adbPath) start-server")
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            _ = await self.shellIgnoringExitCode("\(self.adbPath) reverse --remove-all")
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            return (true, AppText.adbRestarted)
        }

        await run(index: 6) {
            do {
                _ = try await self.shell("\(self.adbPath) reverse tcp:\(self.port) tcp:\(self.port)")
            } catch {
                throw RunnerError.message(AppText.reverseFailed(error.localizedDescription))
            }
            let list = await self.shellIgnoringExitCode("\(self.adbPath) reverse --list")
            self.reverseList = list.trimmingCharacters(in: .whitespacesAndNewlines)
            return (true, AppText.reverseEstablished(self.port))
        }

        await run(index: 7) {
            do {
                _ = try await self.shell("open -a LocalSend")
            } catch {
                throw RunnerError.message(AppText.openLocalSendFailed(error.localizedDescription))
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            return (true, AppText.localSendLaunched)
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
                throw RunnerError.message(msg.isEmpty ? AppText.commandExitCode(proc.terminationStatus) : msg)
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
        display notification "\(AppText.notificationBody)" with title "LocalSend USB"
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
