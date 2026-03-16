import SondeCore
import SwiftUI

@main
struct SondeMenuBarApp: App {
    @StateObject private var viewModel = SondeViewModel()

    init() {
        // Wire toast notifications from SondeCore into the app-layer ToastManager
        NotificationManager.shared.toastHandler = { message, icon in
            ToastManager.shared.show(message: message, icon: icon)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView(viewModel: viewModel)
        } label: {
            MenuBarLabel(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Menu bar display style.
enum MenuBarStyle: String, CaseIterable {
    case emojiPercent = "Emoji + %"
    case emojiCost = "Emoji + Cost"
    case percentOnly = "% Only"
    case costOnly = "Cost Only"
    case emojiPercentCost = "All"
}

/// The tiny label shown in the menu bar.
struct MenuBarLabel: View {
    @ObservedObject var viewModel: SondeViewModel
    @AppStorage("menuBarStyle") private var style: String = MenuBarStyle.emojiPercentCost.rawValue

    var body: some View {
        HStack(spacing: 4) {
            if viewModel.isLoading {
                Text("sonde")
            } else {
                let s = MenuBarStyle(rawValue: style) ?? .emojiPercentCost

                if s == .emojiPercent || s == .emojiCost || s == .emojiPercentCost {
                    Text(viewModel.paceTier.emoji)
                }

                if s == .emojiPercent || s == .percentOnly || s == .emojiPercentCost {
                    if let util = viewModel.fiveHourUtil {
                        Text("\(Int(util))%")
                            .monospacedDigit()
                    }
                }

                if s == .emojiCost || s == .costOnly || s == .emojiPercentCost {
                    if let cost = viewModel.session.sessionCost {
                        Text("$\(String(format: "%.2f", cost))")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
