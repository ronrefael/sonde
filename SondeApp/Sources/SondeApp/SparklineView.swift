import SwiftUI

/// A mini line chart that visualises recent usage values.
struct SparklineView: View {
    let data: [Double]

    var body: some View {
        if data.isEmpty {
            EmptyView()
        } else {
            Canvas { context, size in
                let count = data.count
                guard count > 1 else { return }

                let maxVal = max(data.max() ?? 1, 1)
                let stepX = size.width / CGFloat(count - 1)
                let inset: CGFloat = 2

                var path = Path()
                for (index, value) in data.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = inset + (size.height - inset * 2) * (1 - CGFloat(max(value, 0) / maxVal))
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                let gradient = Gradient(colors: [.green, .yellow, .orange, .red])
                let shading = GraphicsContext.Shading.linearGradient(
                    gradient,
                    startPoint: CGPoint(x: 0, y: size.height),
                    endPoint: CGPoint(x: 0, y: 0)
                )

                context.stroke(path, with: shading, lineWidth: 1.5)
            }
            .frame(width: 60, height: 24)
        }
    }
}
