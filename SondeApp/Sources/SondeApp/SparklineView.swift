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

                let gradient = Gradient(colors: [.green, .yellow, .red])
                let shading = GraphicsContext.Shading.linearGradient(
                    gradient,
                    startPoint: CGPoint(x: 0, y: size.height),
                    endPoint: CGPoint(x: 0, y: 0)
                )

                context.stroke(path, with: shading, lineWidth: 2)
            }
            .frame(width: 60, height: 24)
        }
    }
}
