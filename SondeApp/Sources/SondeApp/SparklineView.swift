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

                let stepX = size.width / CGFloat(count - 1)

                var path = Path()
                for (index, value) in data.enumerated() {
                    let clamped = min(max(value, 0), 100)
                    let x = CGFloat(index) * stepX
                    let y = size.height - (CGFloat(clamped) / 100.0) * size.height
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                let lastValue = min(max(data.last ?? 0, 0), 100)
                let color: Color = lastValue >= 80 ? .red : lastValue >= 50 ? .yellow : .green

                let gradient = Gradient(colors: [.green, .yellow, .red])
                let linearGradient = GraphicsContext.Shading.linearGradient(
                    gradient,
                    startPoint: CGPoint(x: 0, y: size.height),
                    endPoint: CGPoint(x: 0, y: 0)
                )

                _ = color // suppress unused warning; gradient is used instead
                context.stroke(path, with: linearGradient, lineWidth: 1.5)
            }
            .frame(width: 50, height: 16)
        }
    }
}
