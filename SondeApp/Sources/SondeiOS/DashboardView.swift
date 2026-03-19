import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: iOSViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if !viewModel.isConnected {
                        ConnectionCard()
                    }

                    UsageRingCard(
                        fiveHourUtil: viewModel.fiveHourUtil ?? 0,
                        dailyCost: viewModel.dailyCost,
                        paceTier: viewModel.paceTier
                    )

                    PacingCard(
                        paceTier: viewModel.paceTier,
                        fiveHourUtil: viewModel.fiveHourUtil,
                        sevenDayUtil: viewModel.sevenDayUtil,
                        fiveHourReset: viewModel.fiveHourReset,
                        promoActive: viewModel.promoActive
                    )

                    if !viewModel.usageHistory.isEmpty {
                        HistoryCard(data: viewModel.usageHistory)
                    }

                    if let updated = viewModel.lastUpdated {
                        Text("Updated \(updated, style: .relative) ago")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Sonde")
            .refreshable {
                viewModel.loadFromCloud()
            }
        }
    }
}
