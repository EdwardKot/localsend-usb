import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var runner = SetupRunner()

    var body: some View {
        ZStack {
            // Background
            Color(nsColor: NSColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1))
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Title bar area
                TitleBar()

                Divider()
                    .background(Color.white.opacity(0.08))

                // Main content
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Steps list
                        VStack(spacing: 2) {
                            ForEach(Array(runner.steps.enumerated()), id: \.element.id) { i, step in
                                StepRow(index: i + 1, step: step)
                            }
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)

                        // Reverse list (shown on success)
                        if !runner.reverseList.isEmpty {
                            ReverseInfoBox(text: runner.reverseList)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 8)
                        }

                        if runner.phase == .done {
                            NextStepsBox()
                                .padding(.horizontal, 20)
                                .padding(.bottom, 8)
                        }

                        // Error box
                        if runner.phase == .failed {
                            ErrorBox(message: runner.errorMessage)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 8)
                        }
                    }
                }

                Divider()
                    .background(Color.white.opacity(0.08))

                // Bottom action bar
                BottomBar(runner: runner)
            }
        }
        .sheet(isPresented: Binding(
            get: { runner.phase == .confirming },
            set: { if !$0 { runner.phase = .ready } }
        )) {
            ConfirmSheet(onContinue: { runner.proceedAfterConfirm() },
                         onCancel: { runner.phase = .ready })
        }
    }
}

// MARK: - Title Bar

struct TitleBar: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "cable.connector")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(
                    LinearGradient(colors: [Color(hex: "#5AC8FA"), Color(hex: "#34C759")],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text("LocalSend USB")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(AppText.subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.45))
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

// MARK: - Step Row

struct StepRow: View {
    let index: Int
    let step: Step

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Index / state indicator
            ZStack {
                Circle()
                    .fill(bgColor)
                    .frame(width: 26, height: 26)

                switch step.state {
                case .running:
                    ProgressView()
                        .scaleEffect(0.55)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                case .success:
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                case .failure:
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                default:
                    Text("\(index)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(step.state == .idle ? .white.opacity(0.35) : .white)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(step.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(labelColor)

                if !step.detail.isEmpty {
                    Text(step.detail)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(3)
                }
            }

            Spacer()
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(rowBg)
        )
        .animation(.easeInOut(duration: 0.2), value: step.state)
    }

    var bgColor: Color {
        switch step.state {
        case .idle: return Color.white.opacity(0.08)
        case .running: return Color(hex: "#5AC8FA").opacity(0.25)
        case .success: return Color(hex: "#34C759").opacity(0.8)
        case .failure: return Color(hex: "#FF3B30").opacity(0.8)
        case .skipped: return Color.white.opacity(0.15)
        }
    }

    var labelColor: Color {
        switch step.state {
        case .idle: return .white.opacity(0.35)
        case .running: return .white
        case .success: return .white
        case .failure: return Color(hex: "#FF6B6B")
        case .skipped: return .white.opacity(0.45)
        }
    }

    var rowBg: Color {
        switch step.state {
        case .running: return Color(hex: "#5AC8FA").opacity(0.05)
        case .failure: return Color(hex: "#FF3B30").opacity(0.05)
        default: return .clear
        }
    }
}

// MARK: - Reverse Info Box

struct ReverseInfoBox: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#34C759"))

                Text(AppText.reverseListTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "#34C759"))
            }

            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color(hex: "#34C759"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "#34C759").opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(hex: "#34C759").opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Next Steps Box

struct NextStepsBox: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#5AC8FA"))
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 6) {
                Text(AppText.nextStepsTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)

                Text(AppText.nextStepsBody)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "#5AC8FA").opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(hex: "#5AC8FA").opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Error Box

struct ErrorBox: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#FF9F0A"))
                .padding(.top, 1)

            Text(message)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#FFD60A"))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "#FF9F0A").opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(hex: "#FF9F0A").opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Bottom Bar

struct BottomBar: View {
    @ObservedObject var runner: SetupRunner

    var body: some View {
        HStack {
            // Status text
            Group {
                switch runner.phase {
                case .ready:
                    Label(AppText.statusReady, systemImage: "circle.dotted")
                        .foregroundColor(.white.opacity(0.35))
                case .confirming:
                    Label(AppText.statusWaitingConfirm, systemImage: "ellipsis.circle")
                        .foregroundColor(Color(hex: "#5AC8FA"))
                case .running:
                    Label(AppText.statusRunning, systemImage: "arrow.clockwise")
                        .foregroundColor(Color(hex: "#5AC8FA"))
                case .done:
                    Label(AppText.statusDone, systemImage: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "#34C759"))
                case .failed:
                    Label(AppText.statusFailed, systemImage: "xmark.circle.fill")
                        .foregroundColor(Color(hex: "#FF3B30"))
                }
            }
            .font(.system(size: 12, weight: .medium))

            Spacer()

            // Buttons
            if runner.phase == .failed || runner.phase == .done {
                Button(AppText.rerun) {
                    runner.reset()
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            if runner.phase == .done {
                Button(AppText.quit) {
                    NSApp.terminate(nil)
                }
                .buttonStyle(PrimaryButtonStyle())
            }

            if runner.phase == .ready || runner.phase == .failed {
                Button(runner.phase == .failed ? AppText.retry : AppText.start) {
                    if runner.phase == .failed { runner.reset() }
                    runner.start()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

// MARK: - Confirm Sheet

struct ConfirmSheet: View {
    let onContinue: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color(nsColor: NSColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1))
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(colors: [Color(hex: "#FF9F0A"), Color(hex: "#FF6B35")],
                                       startPoint: .top, endPoint: .bottom)
                    )

                Text(AppText.confirmTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 10) {
                    ConfirmItem(icon: "iphone", text: AppText.confirmAndroidClosed)
                    ConfirmItem(icon: "lock.open", text: AppText.confirmEncryptionOff)
                    ConfirmItem(icon: "cable.connector", text: AppText.confirmUSBReady)
                }
                .padding(.horizontal, 8)

                HStack(spacing: 12) {
                    Button(AppText.cancel) { onCancel() }
                        .buttonStyle(SecondaryButtonStyle())

                    Button(AppText.continueConfirmed) { onContinue() }
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(32)
        }
        .frame(width: 360)
    }
}

struct ConfirmItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#5AC8FA"))
                .frame(width: 18)

            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.black)
            .padding(.horizontal, 18)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "#5AC8FA"))
                    .opacity(configuration.isPressed ? 0.7 : 1)
            )
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13))
            .foregroundColor(.white.opacity(0.7))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.12 : 0.08))
            )
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
