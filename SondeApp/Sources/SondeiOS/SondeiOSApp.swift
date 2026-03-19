import SwiftUI

@main
struct SondeiOSApp: App {
    @StateObject private var viewModel = iOSViewModel()

    var body: some Scene {
        WindowGroup {
            DashboardView(viewModel: viewModel)
        }
    }
}
