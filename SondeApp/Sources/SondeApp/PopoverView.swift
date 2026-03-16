import SwiftUI
import SondeCore

/// The popover dashboard shown when clicking the menu bar icon.
struct PopoverView: View {
    @ObservedObject var viewModel: SondeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("sonde")
                    .font(.headline)
                Spacer()
                if !viewModel.promoEmoji.isEmpty {
                    PromoBadge(
                        emoji: viewModel.promoEmoji,
                        label: viewModel.promoLabel,
                        isActive: viewModel.promoActive
                    )
                }
            }

            Divider()

            // Pacing
            PacingRow(tier: viewModel.paceTier)

            // Usage limits
            if let fh = viewModel.fiveHourUtil {
                UsageRow(
                    label: "5-hour",
                    utilization: fh,
                    resetTime: viewModel.fiveHourReset
                )
            }

            if let sd = viewModel.sevenDayUtil {
                UsageRow(
                    label: "7-day",
                    utilization: sd,
                    resetTime: viewModel.sevenDayReset
                )
            }

            if let extra = viewModel.extraUsageUtil {
                UsageRow(
                    label: "Extra",
                    utilization: extra,
                    resetTime: nil
                )
            }

            Divider()

            // Footer
            HStack {
                Button("Refresh") {
                    Task { await viewModel.refresh() }
                }
                .buttonStyle(.borderless)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(16)
        .frame(width: 280)
        .onAppear {
            viewModel.startPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }
}

// MARK: - Subviews

struct PromoBadge: View {
    let emoji: String
    let label: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 2) {
            Text(emoji)
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(isActive ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
        .cornerRadius(4)
    }
}

struct PacingRow: View {
    let tier: PaceTier

    var body: some View {
        HStack {
            Text(tier.emoji)
            Text(tier.rawValue)
                .font(.title3)
                .fontWeight(.medium)
            Spacer()
        }
    }
}

struct UsageRow: View {
    let label: String
    let utilization: Double
    let resetTime: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let reset = resetTime {
                    Text("resets \(TimeFormatting.formatResetCountdown(from: reset))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: max(0, geo.size.width * CGFloat(utilization / 100.0)), height: 8)
                }
            }
            .frame(height: 8)

            HStack {
                Text("\(Int(utilization))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(barColor)
                Spacer()
            }
        }
    }

    private var barColor: Color {
        if utilization >= 80 { return .red }
        if utilization >= 60 { return .orange }
        if utilization >= 40 { return .yellow }
        return .green
    }
}
