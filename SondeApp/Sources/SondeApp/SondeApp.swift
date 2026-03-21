import AppKit
import SondeCore
import SwiftUI

@main
struct SondeMenuBarApp: App {
    @StateObject private var viewModel = SondeViewModel()
    @AppStorage("pollInterval") private var pollInterval: Double = 30

    init() {
        Self.killOtherInstances()
        NotificationManager.shared.toastHandler = { message, icon in
            ToastManager.shared.show(message: message, icon: icon)
        }
    }

    /// Kill any other running Sonde instances to prevent duplicate menu bar items.
    /// Uses both NSWorkspace API and killall as belt-and-suspenders.
    private static func killOtherInstances() {
        let myPID = ProcessInfo.processInfo.processIdentifier

        // Method 1: NSWorkspace — kill by bundle ID
        let running = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == "dev.sonde.app" && $0.processIdentifier != myPID
        }
        for app in running {
            app.forceTerminate()
        }

        // Method 2: killall by process name, excluding our own PID
        // This catches instances NSWorkspace might miss (e.g. from a different bundle location)
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "for pid in $(pgrep -x SondeApp); do [ \"$pid\" != \"\(myPID)\" ] && kill -9 $pid; done"]
        try? task.run()
        task.waitUntilExit()
    }

    /// Detects app updates/reinstalls and clears cached state that can break
    /// the popover. Preserves user preferences across updates.
    /// Uses a separate defaults suite for the stamp so it survives domain wipes.
    private static func clearStaleDefaultsIfNeeded() {
        let stampSuite = UserDefaults(suiteName: "dev.sonde.app.launcher")!
        let stampKey = "binaryStamp"

        guard let binaryPath = Bundle.main.executablePath,
              let attrs = try? FileManager.default.attributesOfItem(atPath: binaryPath),
              let modDate = attrs[.modificationDate] as? Date,
              let fileSize = attrs[.size] as? Int else { return }

        let currentStamp = "\(modDate.timeIntervalSince1970)_\(fileSize)"
        let savedStamp = stampSuite.string(forKey: stampKey)

        if let saved = savedStamp, saved != currentStamp {
            let defaults = UserDefaults.standard

            // Save user preferences before nuking
            let preserveKeys = [
                "popoverTheme", "appearanceMode", "showMenuBarPromo",
                "showMenuBarCountdown", "menuBarTimerMode", "pollInterval",
                "hasCompletedOnboarding"
            ]
            var preserved: [String: Any] = [:]
            for key in preserveKeys {
                if let val = defaults.object(forKey: key) {
                    preserved[key] = val
                }
            }

            // Nuke all domains
            for domain in ["dev.sonde.app", "dev.sonde.app.widget", "dev.sonde.core"] {
                defaults.removePersistentDomain(forName: domain)
            }
            defaults.synchronize()

            // Restore saved preferences
            for (key, val) in preserved {
                defaults.set(val, forKey: key)
            }
            defaults.synchronize()
        }

        stampSuite.set(currentStamp, forKey: stampKey)
        stampSuite.synchronize()
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView(viewModel: viewModel)
        } label: {
            MenuBarLabel(viewModel: viewModel)
                .onAppear { viewModel.startPolling(interval: pollInterval) }
                .onDisappear { viewModel.stopPolling() }
                .onChange(of: pollInterval) { newInterval in
                    viewModel.startPolling(interval: newInterval)
                }
        }
        .menuBarExtraStyle(.window)
    }
}

/// The tiny label shown in the menu bar.
/// Shows: remaining % | reset countdown (optionally 2x prefix).
struct MenuBarLabel: View {
    @ObservedObject var viewModel: SondeViewModel
    @AppStorage("showMenuBarPromo") private var showMenuBarPromo: Bool = true
    @AppStorage("showMenuBarCountdown") private var showMenuBarCountdown: Bool = true
    @AppStorage("menuBarTimerMode") private var menuBarTimerMode: String = "5h_left"

    var body: some View {
        let text = labelText
        HStack(spacing: 4) {
            if !viewModel.isLoading, viewModel.fiveHourUtil != nil {
                Image(systemName: paceTierIcon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(paceTierColor)
            }
            if !text.isEmpty {
                if !viewModel.isLoading, viewModel.fiveHourUtil != nil {
                    Text("| \(text)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                } else {
                    Text(text)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                }
            }
        }
    }

    private var labelText: String {
        if viewModel.isLoading { return "sonde" }
        var parts: [String] = []

        // Promo multiplier when active (2x, 3x, or ⚡)
        if showMenuBarPromo && viewModel.promoActive {
            let label = viewModel.promoShortLabel
            parts.append(label.isEmpty ? "⚡" : label)
        }

        // Remaining percentage
        if let util = viewModel.fiveHourUtil {
            parts.append("\(min(100, max(0, Int(util))))% used")
        }

        // Timer (configurable mode)
        if showMenuBarCountdown {
            let timerText: String = {
                switch menuBarTimerMode {
                case "5h_left":
                    guard let reset = viewModel.fiveHourReset else { return "" }
                    return TimeFormatting.formatResetCountdown(from: reset)

                case "5h_elapsed":
                    guard let reset = viewModel.fiveHourReset else { return "" }
                    let isoFmt = ISO8601DateFormatter()
                    isoFmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    guard let resetDate = isoFmt.date(from: reset)
                            ?? ISO8601DateFormatter().date(from: reset) else { return "" }
                    let windowStart = resetDate.addingTimeInterval(-5 * 3600)
                    let elapsed = max(0, Int(Date().timeIntervalSince(windowStart) / 60))
                    let h = elapsed / 60; let m = elapsed % 60
                    return h > 0 ? "\(h)h\(String(format: "%02d", m))m" : "\(m)m"

                case "5h_reset_time":
                    guard let reset = viewModel.fiveHourReset else { return "" }
                    return TimeFormatting.formatResetTime(from: reset)

                case "7d_left":
                    guard let reset = viewModel.sevenDayReset else { return "" }
                    return TimeFormatting.formatResetCountdown(from: reset)

                case "7d_reset_time":
                    guard let reset = viewModel.sevenDayReset else { return "" }
                    return TimeFormatting.formatResetTime(from: reset)

                case "promo_left":
                    if viewModel.promoActive { return viewModel.promoCountdown }
                    guard let reset = viewModel.fiveHourReset else { return "" }
                    return TimeFormatting.formatResetCountdown(from: reset)

                case "session":
                    let dur = viewModel.liveSessionDuration
                    return dur.isEmpty ? "" : dur

                default:
                    guard let reset = viewModel.fiveHourReset else { return "" }
                    return TimeFormatting.formatResetCountdown(from: reset)
                }
            }()

            if !timerText.isEmpty {
                parts.append(timerText)
            }
        }

        if parts.isEmpty { return viewModel.fiveHourUtil != nil ? "" : "sonde" }
        return parts.joined(separator: " | ")
    }

    private var paceTierIcon: String { viewModel.paceTier.icon }
    private var paceTierColor: Color { viewModel.paceTier.swiftColor }
}
