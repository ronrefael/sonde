import SondeCore
import SwiftUI

@main
struct SondeMenuBarApp: App {
    @StateObject private var viewModel = SondeViewModel()

    // NOTE: MenuBarExtra does not support .keyboardShortcut() as of macOS 14.
    // A global keyboard shortcut (e.g. Cmd+Shift+S) to toggle the popover would
    // require either NSEvent.addGlobalMonitorForEvents or registering a global
    // hotkey via Carbon/HIDKit, which is beyond MenuBarExtra's built-in API.
    // Consider adding a global hotkey listener in a future version.
    var body: some Scene {
        MenuBarExtra {
            PopoverView(viewModel: viewModel)
        } label: {
            MenuBarLabel(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}

/// The tiny label shown in the menu bar.
struct MenuBarLabel: View {
    @ObservedObject var viewModel: SondeViewModel

    var body: some View {
        HStack(spacing: 4) {
            if viewModel.isLoading {
                Text("sonde")
            } else {
                Text(viewModel.paceTier.emoji)
                if let util = viewModel.fiveHourUtil {
                    Text("\(Int(util))%")
                        .monospacedDigit()
                }
                if let cost = viewModel.session.sessionCost {
                    Text("$\(String(format: "%.2f", cost))")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
