import SondeCore
import SwiftUI

/// A bar chart showing the 5-hour peak utilization for the last 14 days.
struct HistoryChartView: View {
    let history: [DailySnapshot]

    var body: some View {
        if history.isEmpty {
            Text("No history yet")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 280, height: 100)
        } else {
            VStack(spacing: 4) {
                // Chart area
                HStack(alignment: .bottom, spacing: 2) {
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
                    .frame(width: 20, height: 80)

                    ForEach(Array(history.enumerated()), id: \.offset) { _, snapshot in
                        VStack(spacing: 2) {
                            GeometryReader { geo in
                                let pct = min(snapshot.fiveHourPeak, 100) / 100.0
                                let barHeight = max(1, geo.size.height * CGFloat(pct))
                                VStack {
                                    Spacer()
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(barColor(for: snapshot.fiveHourPeak))
                                        .frame(height: barHeight)
                                }
                            }
                            .frame(height: 72)

                            Text(dayLabel(for: snapshot.date))
                                .font(.system(size: 7))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(width: 280, height: 88)
            }
            .frame(width: 280, height: 100)
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
        // Return first 2-3 chars (Mon, Tue, etc.)
        return String(full.prefix(3))
    }
}
