import SondeCore
import SwiftUI

/// A bar chart showing the 5-hour peak utilization for the last 14 days.
/// Adapts to its container size when no explicit frame is set.
struct HistoryChartView: View {
    let history: [DailySnapshot]
    var compact: Bool = false

    var body: some View {
        if history.isEmpty {
            Text("No history yet")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, minHeight: compact ? 50 : 100)
        } else {
            GeometryReader { outer in
                let chartHeight = compact ? outer.size.height : min(outer.size.height, 88)
                let barHeight = chartHeight - (compact ? 10 : 16)

                HStack(alignment: .bottom, spacing: compact ? 1.5 : 2) {
                    if !compact {
                        // Y-axis label
                        VStack {
                            Text("100")
                                .font(.system(size: 7))
                                .foregroundStyle(.tertiary)
                            Spacer()
                            Text("50")
                                .font(.system(size: 7))
                                .foregroundStyle(.tertiary)
                            Spacer()
                            Text("0")
                                .font(.system(size: 7))
                                .foregroundStyle(.tertiary)
                        }
                        .frame(width: 20, height: barHeight)
                    }

                    ForEach(Array(history.enumerated()), id: \.offset) { _, snapshot in
                        VStack(spacing: compact ? 1 : 2) {
                            GeometryReader { geo in
                                let pct = min(snapshot.fiveHourPeak, 100) / 100.0
                                let h = max(1, geo.size.height * CGFloat(pct))
                                VStack {
                                    Spacer()
                                    RoundedRectangle(cornerRadius: compact ? 1.5 : 2)
                                        .fill(barColor(for: snapshot.fiveHourPeak))
                                        .frame(height: h)
                                }
                            }
                            .frame(height: barHeight)

                            if !compact {
                                Text(dayLabel(for: snapshot.date))
                                    .font(.system(size: 7))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
    }

    private func barColor(for utilization: Double) -> Color {
        if utilization >= 80 { return .red }
        if utilization >= 60 { return .orange }
        if utilization >= 40 { return .yellow }
        return .green
    }

    private func dayLabel(for dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return "?" }
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"
        let full = dayFormatter.string(from: date)
        return String(full.prefix(3))
    }
}
