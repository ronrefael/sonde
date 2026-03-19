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

    var body: some View {
        HStack(spacing: 4) {
            // Pace tier icon with color
            if !viewModel.isLoading, viewModel.fiveHourUtil != nil {
                Image(systemName: paceTierIcon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(paceTierColor)
            }
            Text(labelText)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .monospacedDigit()
        }
    }

    private var labelText: String {
        if viewModel.isLoading { return "sonde" }
        var parts: [String] = []

        // Daily spend total
        let dailyTotal = viewModel.dailyClaudeCost + viewModel.dailyCodexCost
        if dailyTotal > 0 {
            parts.append(String(format: "$%.2f", dailyTotal))
        }

        // 2x prefix when promo active
        if viewModel.promoActive { parts.append("2x") }

        // Remaining percentage
        if let util = viewModel.fiveHourUtil {
            parts.append("\(max(0, Int(100 - util)))%")
        }

        // Reset countdown
        if let reset = viewModel.fiveHourReset {
            parts.append(TimeFormatting.formatResetCountdown(from: reset))
        }

        return parts.isEmpty ? "sonde" : parts.joined(separator: " | ")
    }

    private var paceTierIcon: String { viewModel.paceTier.icon }
    private var paceTierColor: Color { viewModel.paceTier.swiftColor }
}
