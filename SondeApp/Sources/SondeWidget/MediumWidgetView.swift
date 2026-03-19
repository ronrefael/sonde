import SwiftUI
import WidgetKit

struct PacingDashboardWidget: Widget {
    let kind = "dev.sonde.app.widget.pacing"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SondeTimelineProvider()) { entry in
            MediumWidgetView(entry: entry)
        }
        .configurationDisplayName("Pacing Dashboard")
        .description("Pacing tier with 5-hour and 7-day usage")
        .supportedFamilies([.systemMedium])
    }
}

struct MediumWidgetView: View {
    let entry: SondeEntry

    private var tierColor: Color {
        switch entry.paceTier {
        case "Comfortable": .green
        case "On Track": .blue
        case "Elevated": .yellow
        case "Hot": .orange
        case "Critical", "Runaway": .red
        default: .blue
        }
    }

    private var tierIcon: String {
        switch entry.paceTier {
        case "Comfortable": "checkmark.circle.fill"
        case "On Track": "checkmark.circle"
        case "Elevated": "exclamationmark.triangle.fill"
        case "Hot": "flame.fill"
        case "Critical": "xmark.octagon.fill"
        case "Runaway": "nosign"
        default: "checkmark.circle"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Left: Pace tier
            VStack(spacing: 4) {
                Image(systemName: tierIcon)
                    .font(.title2)
                    .foregroundStyle(tierColor)
                Text(entry.paceTier)
                    .font(.caption.bold())
                    .foregroundStyle(tierColor)
                if entry.promoActive {
                    Text("2\u{00D7}")
                        .font(.caption2.bold())
                        .foregroundStyle(.green)
                }
            }
            .frame(width: 60)

            // Center: Usage bars
            VStack(alignment: .leading, spacing: 8) {
                UsageBarRow(label: "5h", value: entry.fiveHourUtil, color: tierColor)
                UsageBarRow(label: "7d", value: entry.sevenDayUtil, color: .blue)

                Text("$\(entry.dailyCost, specifier: "%.2f") today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Right: Reset countdown
            if let reset = entry.fiveHourReset {
                VStack(spacing: 2) {
                    Text("Resets")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(reset, style: .relative)
                        .font(.caption.monospacedDigit())
                        .multilineTextAlignment(.center)
                }
                .frame(width: 60)
            }
        }
        .padding()
        .widgetBackground()
    }
}

// MARK: - Usage Bar Row

struct UsageBarRow: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption.bold())
                .frame(width: 20, alignment: .trailing)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.2))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: max(0, geo.size.width * min(value / 100.0, 1.0)))
                }
            }
            .frame(height: 8)

            Text("\(Int(value))%")
                .font(.caption.monospacedDigit())
                .frame(width: 32, alignment: .trailing)
        }
    }
}
