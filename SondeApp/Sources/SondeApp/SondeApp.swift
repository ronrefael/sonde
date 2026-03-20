import SondeCore
import SwiftUI

@main
struct SondeMenuBarApp: App {
    @StateObject private var viewModel = SondeViewModel()
    @AppStorage("pollInterval") private var pollInterval: Double = 30

    init() {
        NotificationManager.shared.toastHandler = { message, icon in
            ToastManager.shared.show(message: message, icon: icon)
        }
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
/// Shows: daily spend | remaining % | reset countdown (optionally 2x prefix).
struct MenuBarLabel: View {
    @ObservedObject var viewModel: SondeViewModel
    @AppStorage("showCosts") private var showCosts: Bool = false
    @AppStorage("showMenuBarCost") private var showMenuBarCost: Bool = true
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

        // Daily spend total — only show when enabled and there's a real cost
        if showMenuBarCost && showCosts {
            let dailyTotal = viewModel.dailyClaudeCost + viewModel.dailyCodexCost
            if dailyTotal >= 0.01 {
                parts.append(String(format: "$%.2f", dailyTotal))
            }
        }

        // Promo multiplier when active (2x, 3x, or ⚡)
        if showMenuBarPromo && viewModel.promoActive {
            let label = viewModel.promoShortLabel
            parts.append(label.isEmpty ? "⚡" : label)
        }

        // Remaining percentage
        if let util = viewModel.fiveHourUtil {
            parts.append("\(max(0, Int(100 - util)))%")
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
                    let remaining = TimeFormatting.remainingMinutes(from: reset)
                    guard remaining > 0 else { return "" }
                    let elapsed = max(0, 300 - remaining)
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
                    guard viewModel.promoActive else { return "" }
                    return viewModel.promoCountdown

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
