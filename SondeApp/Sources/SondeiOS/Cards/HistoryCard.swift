import SwiftUI

/// Simple sparkline chart of recent usage history.
struct HistoryCard: View {
    let data: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Usage")
                .font(.headline)

            SparklineView(values: data)
                .frame(height: 60)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

/// A minimal sparkline drawn with a Path.
struct SparklineView: View {
    let values: [Double]

    var body: some View {
        GeometryReader { geo in
            let maxVal = max(values.max() ?? 1, 1)
            let stepX = geo.size.width / max(CGFloat(values.count - 1), 1)

            ZStack {
                // Filled area
                Path { path in
                    guard !values.isEmpty else { return }
                    let firstY = geo.size.height * (1 - CGFloat(values[0] / maxVal))
                    path.move(to: CGPoint(x: 0, y: firstY))

                    for i in 1..<values.count {
                        let x = stepX * CGFloat(i)
                        let y = geo.size.height * (1 - CGFloat(values[i] / maxVal))
                        path.addLine(to: CGPoint(x: x, y: y))
                    }

                    // Close area to bottom
                    path.addLine(to: CGPoint(x: stepX * CGFloat(values.count - 1), y: geo.size.height))
                    path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [sparkColor.opacity(0.3), sparkColor.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Line
                Path { path in
                    guard !values.isEmpty else { return }
                    let firstY = geo.size.height * (1 - CGFloat(values[0] / maxVal))
                    path.move(to: CGPoint(x: 0, y: firstY))

                    for i in 1..<values.count {
                        let x = stepX * CGFloat(i)
                        let y = geo.size.height * (1 - CGFloat(values[i] / maxVal))
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                .stroke(sparkColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private var sparkColor: Color {
        guard let last = values.last else { return .blue }
        if last >= 80 { return .red }
        if last >= 60 { return .orange }
        return .blue
    }
}
