import SondeCore
import SwiftUI

@main
struct SondeMenuBarApp: App {
    @StateObject private var viewModel = SondeViewModel()

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
                .onAppear { viewModel.startPolling() }
                .onDisappear { viewModel.stopPolling() }
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

    var body: some View {
        let text = labelText
        HStack(spacing: 3) {
            if !viewModel.isLoading, viewModel.fiveHourUtil != nil {
                Image(systemName: paceTierIcon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(paceTierColor)
            }
            if !text.isEmpty {
                Text(text)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .monospacedDigit()
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

        // Reset countdown
        if showMenuBarCountdown, let reset = viewModel.fiveHourReset {
            let countdown = TimeFormatting.formatResetCountdown(from: reset)
            if !countdown.isEmpty {
                parts.append(countdown)
            }
        }

        if parts.isEmpty { return viewModel.fiveHourUtil != nil ? "" : "sonde" }
        return parts.joined(separator: " | ")
    }

    private var paceTierIcon: String { viewModel.paceTier.icon }
    private var paceTierColor: Color { viewModel.paceTier.swiftColor }
}
