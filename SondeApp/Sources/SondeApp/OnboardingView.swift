import AppKit
import SondeCore
import SwiftUI

// MARK: - Onboarding Flow

/// Six-step onboarding flow shown on first launch.
struct OnboardingView: View {
    let theme: PopoverTheme
    let onComplete: () -> Void

    @State private var currentStep = 0
    @AppStorage("popoverTheme") private var selectedTheme: String = PopoverTheme.system.rawValue

    private let totalSteps = 6

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentStep) {
                WelcomeStep(theme: theme) {
                    withAnimation { currentStep = 1 }
                }
                .tag(0)

                ClaudeCheckStep(theme: theme)
                    .tag(1)

                AuthCheckStep(theme: theme)
                    .tag(2)

                StatuslineStep(theme: theme)
                    .tag(3)

                ThemeStep(theme: theme, selectedTheme: $selectedTheme)
                    .tag(4)

                DoneStep(theme: theme, onComplete: onComplete)
                    .tag(5)
            }
            .tabViewStyle(.automatic)
            .animation(.easeInOut(duration: 0.3), value: currentStep)

            // Navigation controls
            if currentStep > 0 {
                Divider().overlay(theme.dividerColor)

                HStack {
                    if currentStep > 0 {
                        Button {
                            withAnimation { currentStep = max(0, currentStep - 1) }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("Back")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(theme.headerAccent)
                        }
                        .buttonStyle(.borderless)
                    }

                    Spacer()

                    // Page dots
                    HStack(spacing: 6) {
                        ForEach(0..<totalSteps, id: \.self) { step in
                            Circle()
                                .fill(step == currentStep ? theme.headerAccent : theme.borderColor)
                                .frame(width: 6, height: 6)
                        }
                    }

                    Spacer()

                    if currentStep < totalSteps - 1 {
                        Button {
                            withAnimation { currentStep = min(totalSteps - 1, currentStep + 1) }
                        } label: {
                            HStack(spacing: 4) {
                                Text("Next")
                                    .font(.system(size: 12, weight: .medium))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(theme.headerAccent)
                        }
                        .buttonStyle(.borderless)
                    } else {
                        // Invisible spacer to balance the layout
                        Text("Next").font(.system(size: 12)).hidden()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }
}

// MARK: - Step 1: Welcome

private struct WelcomeStep: View {
    let theme: PopoverTheme
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            SondeLogoMascot()
                .frame(width: 80, height: 80)

            VStack(spacing: 8) {
                HStack(spacing: 0) {
                    Text("Welcome to ")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(theme.textPrimary)
                    Text("sond")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(red: 0.114, green: 0.620, blue: 0.459))
                    Text("e")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color(red: 0.114, green: 0.620, blue: 0.459))
                }

                Text("Precision instrumentation for your AI usage.\nMonitor rate limits, sessions, and pacing in real-time.")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Spacer()

            Button(action: onStart) {
                Text("Get Started")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.114, green: 0.620, blue: 0.459), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.borderless)

            Spacer().frame(height: 30)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Step 2: Claude Check

private struct ClaudeCheckStep: View {
    let theme: PopoverTheme
    @State private var claudeFound = false
    @State private var hasChecked = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: claudeFound ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(claudeFound ? theme.lowUtilColor : theme.highUtilColor)

            VStack(spacing: 8) {
                Text("Claude Code")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(theme.textPrimary)

                if hasChecked {
                    if claudeFound {
                        Text("Claude Code is installed.")
                            .font(.system(size: 13))
                            .foregroundStyle(theme.lowUtilColor)
                    } else {
                        VStack(spacing: 8) {
                            Text("Claude Code was not detected.")
                                .font(.system(size: 13))
                                .foregroundStyle(theme.highUtilColor)

                            Text("Install Claude Code to use sonde.")
                                .font(.system(size: 12))
                                .foregroundStyle(theme.textSecondary)

                            Button {
                                if let url = URL(string: "https://docs.anthropic.com/en/docs/claude-code/overview") {
                                    NSWorkspace.shared.open(url)
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.system(size: 11))
                                    Text("Download Claude Code")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundStyle(theme.headerAccent)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(theme.headerAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                } else {
                    Text("Checking for Claude Code installation...")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.textSecondary)
                }
            }

            Button {
                checkClaude()
            } label: {
                Text("Check Again")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.headerAccent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(theme.headerAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.borderless)

            Spacer()
        }
        .padding(.horizontal, 24)
        .onAppear { checkClaude() }
    }

    private func checkClaude() {
        let homeDir = realHomeDir()
        let claudeDir = homeDir.appendingPathComponent(".claude")
        claudeFound = FileManager.default.fileExists(atPath: claudeDir.path)
        hasChecked = true
    }
}

// MARK: - Step 3: Auth Check

private struct AuthCheckStep: View {
    let theme: PopoverTheme
    @State private var tokenFound = false
    @State private var hasChecked = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: tokenFound ? "checkmark.shield.fill" : "shield.slash")
                .font(.system(size: 48))
                .foregroundStyle(tokenFound ? theme.lowUtilColor : theme.highUtilColor)

            VStack(spacing: 8) {
                Text("Authentication")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(theme.textPrimary)

                if hasChecked {
                    if tokenFound {
                        Text("OAuth token found. You're signed in.")
                            .font(.system(size: 13))
                            .foregroundStyle(theme.lowUtilColor)
                    } else {
                        VStack(spacing: 8) {
                            Text("OAuth token not found.")
                                .font(.system(size: 13))
                                .foregroundStyle(theme.highUtilColor)

                            Text("Sign in to Claude Code in your terminal first,\nthen check again.")
                                .font(.system(size: 12))
                                .foregroundStyle(theme.textSecondary)
                                .multilineTextAlignment(.center)

                            HStack(spacing: 4) {
                                Image(systemName: "terminal")
                                    .font(.system(size: 10))
                                Text("claude")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                            }
                            .foregroundStyle(theme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.borderColor, lineWidth: 1))
                        }
                    }
                } else {
                    Text("Checking for OAuth credentials...")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.textSecondary)
                }
            }

            Button {
                checkAuth()
            } label: {
                Text("Check Again")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.headerAccent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(theme.headerAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.borderless)

            Spacer()
        }
        .padding(.horizontal, 24)
        .onAppear { checkAuth() }
    }

    private func checkAuth() {
        tokenFound = CredentialProvider.getOAuthToken() != nil
        hasChecked = true
    }
}

// MARK: - Step 4: Statusline

private struct StatuslineStep: View {
    let theme: PopoverTheme
    @State private var statuslineConfigured = false
    @State private var hasChecked = false
    @State private var isConfiguring = false
    @State private var configError: String?

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: statuslineConfigured ? "checkmark.rectangle.fill" : "rectangle.bottomhalf.inset.filled")
                .font(.system(size: 48))
                .foregroundStyle(statuslineConfigured ? theme.lowUtilColor : theme.headerAccent)

            VStack(spacing: 8) {
                Text("Terminal Statusline")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(theme.textPrimary)

                if statuslineConfigured {
                    Text("Statusline is already configured.")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.lowUtilColor)
                } else {
                    Text("Enable the statusline in Claude Code to\nfeed live data to sonde.")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            // Preview of statusline
            HStack(spacing: 6) {
                Text("Opus")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.purple, in: RoundedRectangle(cornerRadius: 3))
                Text("|")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(theme.textSecondary.opacity(0.4))
                Text("42% 5h")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.lowUtilColor)
                Text("|")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(theme.textSecondary.opacity(0.4))
                Text("12% 7d")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.lowUtilColor)
                Text("|")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(theme.textSecondary.opacity(0.4))
                Text("2h 14m")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))

            if let error = configError {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.highUtilColor)
            }

            if !statuslineConfigured {
                VStack(spacing: 8) {
                    Button {
                        configureStatusline()
                    } label: {
                        HStack(spacing: 4) {
                            if isConfiguring {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text("Enable Statusline")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(theme.headerAccent, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.borderless)
                    .disabled(isConfiguring)

                    Text("Skip")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textSecondary)
                        .help("You can configure this later")
                }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .onAppear { checkStatusline() }
    }

    private func checkStatusline() {
        let homeDir = realHomeDir()
        let settingsPath = homeDir.appendingPathComponent(".claude/settings.json")
        guard let data = try? Data(contentsOf: settingsPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            hasChecked = true
            return
        }
        // Check if env.CLAUDE_CODE_STATUSLINE is set
        if let env = json["env"] as? [String: Any],
           env["CLAUDE_CODE_STATUSLINE"] != nil {
            statuslineConfigured = true
        }
        hasChecked = true
    }

    private func configureStatusline() {
        isConfiguring = true
        configError = nil

        let homeDir = realHomeDir()
        let settingsPath = homeDir.appendingPathComponent(".claude/settings.json")
        let backupPath = homeDir.appendingPathComponent(".claude/settings.json.bak")
        let fm = FileManager.default

        var json: [String: Any] = [:]

        // Read existing settings
        if let data = try? Data(contentsOf: settingsPath),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            json = existing
            // Create backup
            try? fm.copyItem(at: settingsPath, to: backupPath)
        }

        // Set the statusline config
        var env = json["env"] as? [String: Any] ?? [:]
        env["CLAUDE_CODE_STATUSLINE"] = "1"
        json["env"] = env

        // Write back
        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: settingsPath)
            statuslineConfigured = true
            ToastManager.shared.show(message: "Statusline configured!", icon: nil)
        } catch {
            configError = "Failed to write settings: \(error.localizedDescription)"
        }

        isConfiguring = false
    }
}

// MARK: - Step 5: Theme

private struct ThemeStep: View {
    let theme: PopoverTheme
    @Binding var selectedTheme: String

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 8) {
                Text("Choose a Theme")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(theme.textPrimary)

                Text("Pick a look that suits your style.")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.textSecondary)
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(PopoverTheme.allCases, id: \.rawValue) { t in
                    let isSelected = selectedTheme == t.rawValue
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTheme = t.rawValue
                        }
                    } label: {
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(t.popoverBackground)
                                .frame(height: 44)
                                .overlay(
                                    VStack(spacing: 2) {
                                        Circle()
                                            .fill(t.swatchColor)
                                            .frame(width: 14, height: 14)
                                        if isSelected {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundStyle(t.headerAccent)
                                        }
                                    }
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(isSelected ? t.headerAccent : theme.borderColor, lineWidth: isSelected ? 2 : 1)
                                )

                            Text(t.rawValue)
                                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? theme.headerAccent : theme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 8)

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Step 6: Done

private struct DoneStep: View {
    let theme: PopoverTheme
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            SondeLogoMascot()
                .frame(width: 64, height: 64)

            VStack(spacing: 8) {
                Text("You're all set!")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(theme.textPrimary)

                Text("sonde is ready to monitor your AI usage.")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                tipRow(icon: "arrow.clockwise", text: "Click the refresh button or press Cmd+R")
                tipRow(icon: "gearshape", text: "Customize themes and timers in Settings")
                tipRow(icon: "pip", text: "Use the watcher for an always-on-top view")
                tipRow(icon: "bell", text: "Get notified when usage gets high")
            }
            .padding(12)
            .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.borderColor, lineWidth: 1))

            Spacer()

            Button(action: onComplete) {
                Text("Open Dashboard")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.114, green: 0.620, blue: 0.459), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.borderless)

            Spacer().frame(height: 20)
        }
        .padding(.horizontal, 24)
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(theme.headerAccent)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(theme.textPrimary)
        }
    }
}

// MARK: - Status Banners

/// Condition type for status banners.
enum StatusBannerCondition: Identifiable {
    case claudeNotInstalled
    case authMissing
    case dataStale
    case rateLimited

    var id: String {
        switch self {
        case .claudeNotInstalled: return "claude_not_installed"
        case .authMissing: return "auth_missing"
        case .dataStale: return "data_stale"
        case .rateLimited: return "rate_limited"
        }
    }

    var icon: String {
        switch self {
        case .claudeNotInstalled: return "exclamationmark.triangle.fill"
        case .authMissing: return "person.crop.circle.badge.exclamationmark"
        case .dataStale: return "clock.arrow.circlepath"
        case .rateLimited: return "arrow.clockwise"
        }
    }

    var message: String {
        switch self {
        case .claudeNotInstalled: return "Claude Code not detected"
        case .authMissing: return "Sign in to Claude Code"
        case .dataStale: return "Usage data may be outdated"
        case .rateLimited: return "Refreshing..."
        }
    }

    var isError: Bool {
        switch self {
        case .claudeNotInstalled, .authMissing: return true
        case .dataStale, .rateLimited: return false
        }
    }

    var actionURL: URL? {
        switch self {
        case .claudeNotInstalled:
            return URL(string: "https://docs.anthropic.com/en/docs/claude-code/overview")
        default:
            return nil
        }
    }
}

/// A persistent banner view that shows status conditions between the header and session strip.
struct StatusBannerView: View {
    let conditions: [StatusBannerCondition]
    let theme: PopoverTheme
    let onDismiss: (StatusBannerCondition) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(conditions) { condition in
                HStack(spacing: 8) {
                    Image(systemName: condition.icon)
                        .font(.system(size: 11))

                    Text(condition.message)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)

                    Spacer()

                    if let url = condition.actionURL {
                        Button {
                            NSWorkspace.shared.open(url)
                        } label: {
                            Text("Details")
                                .font(.system(size: 10, weight: .medium))
                                .underline()
                        }
                        .buttonStyle(.borderless)
                    }

                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            onDismiss(condition)
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .opacity(0.7)
                    }
                    .buttonStyle(.borderless)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    condition.isError
                        ? theme.highUtilColor.opacity(0.85)
                        : theme.medUtilColor.opacity(0.85)
                )
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Helpers

/// Returns the real (non-sandboxed) home directory.
private func realHomeDir() -> URL {
    if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
        return URL(fileURLWithPath: String(cString: dir))
    }
    return FileManager.default.homeDirectoryForCurrentUser
}
