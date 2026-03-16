import SondeCore
import SwiftUI

@main
struct SondeMenuBarApp: App {
    @StateObject private var viewModel = SondeViewModel()

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
