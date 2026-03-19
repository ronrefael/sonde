import SwiftUI
import WidgetKit

struct UsageRingWidget: Widget {
    let kind = "dev.sonde.app.widget.usage-ring"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SondeTimelineProvider()) { entry in
            SmallWidgetView(entry: entry)
        }
        .configurationDisplayName("Usage Ring")
        .description("Current 5-hour usage and daily cost")
        .supportedFamilies([.systemSmall])
    }
}

struct SmallWidgetView: View {
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

    var body: some View {
        ZStack {
            // Background ring (track)
            Circle()
                .stroke(tierColor.opacity(0.2), lineWidth: 8)

            // Progress ring
            Circle()
                .trim(from: 0, to: min(entry.fiveHourUtil / 100.0, 1.0))
                .stroke(tierColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // Center content
            VStack(spacing: 2) {
                Text("$\(entry.dailyCost, specifier: "%.2f")")
                    .font(.system(.title3, design: .rounded).bold())
                    .minimumScaleFactor(0.6)

                Text("\(Int(entry.fiveHourUtil))%")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .widgetBackground()
        .widgetURL(URL(string: "sonde://open"))
    }
}

// MARK: - macOS 14+ container background compatibility

extension View {
    @ViewBuilder
    func widgetBackground() -> some View {
        if #available(macOS 14.0, *) {
            self.containerBackground(for: .widget) {
                Color(nsColor: .windowBackgroundColor)
            }
        } else {
            self.background(Color(nsColor: .windowBackgroundColor))
        }
    }
}
