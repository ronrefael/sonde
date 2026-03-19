import SwiftUI

/// Shows pace tier, usage bars for 5h/7d windows, and reset countdown.
struct PacingCard: View {
    let paceTier: String
    let fiveHourUtil: Double?
    let sevenDayUtil: Double?
    let fiveHourReset: Date?
    let promoActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Text("Pacing")
                    .font(.headline)
                Spacer()
                if promoActive {
                    Label("2x Off-Peak", systemImage: "bolt.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }

            // 5-hour bar
            usageBar(
                label: "5-hour",
                value: fiveHourUtil,
                resetDate: fiveHourReset
            )

            // 7-day bar
            usageBar(
                label: "7-day",
                value: sevenDayUtil,
                resetDate: nil
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func usageBar(label: String, value: Double?, resetDate: Date?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if let value {
                    Text("\(Int(value))%")
                        .font(.subheadline.weight(.medium))
                        .monospacedDigit()
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))

                    Capsule()
                        .fill(barColor(for: value ?? 0))
                        .frame(width: geo.size.width * min((value ?? 0) / 100.0, 1.0))
                        .animation(.easeInOut(duration: 0.4), value: value)
                }
            }
            .frame(height: 8)

            if let resetDate {
                Text("Resets \(resetDate, style: .relative)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func barColor(for value: Double) -> Color {
        if value >= 90 { return .red }
        if value >= 80 { return .orange }
        if value >= 60 { return .yellow }
        return .green
    }
}
