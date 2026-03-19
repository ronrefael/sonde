import SwiftUI

/// Circular progress ring showing 5-hour utilization with cost and tier.
struct UsageRingCard: View {
    let fiveHourUtil: Double
    let dailyCost: Double
    let paceTier: String

    private var ringColor: Color {
        switch paceTier {
        case "Comfortable": .green
        case "On Track": .blue
        case "Elevated": .yellow
        case "Hot": .orange
        case "Critical", "Runaway": .red
        default: .blue
        }
    }

    private var tierIcon: String {
        switch paceTier {
        case "Comfortable": "checkmark.circle.fill"
        case "On Track": "checkmark.circle"
        case "Elevated": "exclamationmark.triangle.fill"
        case "Hot": "flame.fill"
        case "Critical": "xmark.octagon.fill"
        case "Runaway": "nosign"
        default: "circle"
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(ringColor.opacity(0.15), lineWidth: 14)

                // Progress ring
                Circle()
                    .trim(from: 0, to: min(fiveHourUtil / 100.0, 1.0))
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: fiveHourUtil)

                // Center content
                VStack(spacing: 4) {
                    Text("\(Int(fiveHourUtil))%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()

                    Text("5h usage")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 160, height: 160)

            HStack(spacing: 20) {
                // Pace tier
                HStack(spacing: 6) {
                    Image(systemName: tierIcon)
                        .foregroundStyle(ringColor)
                    Text(paceTier)
                        .font(.subheadline.weight(.medium))
                }

                Divider()
                    .frame(height: 16)

                // Daily cost
                HStack(spacing: 6) {
                    Image(systemName: "dollarsign.circle")
                        .foregroundStyle(.secondary)
                    Text(formattedCost)
                        .font(.subheadline.weight(.medium))
                        .monospacedDigit()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var formattedCost: String {
        if dailyCost < 0.01 { return String(format: "$%.3f", dailyCost) }
        return String(format: "$%.2f", dailyCost)
    }
}
