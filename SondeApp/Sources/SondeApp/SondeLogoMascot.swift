import SwiftUI

/// Pixel-art mascot from the sonde logo, rendered as SwiftUI rectangles.
/// Matches assets/logo-wordmark.svg exactly.
struct SondeLogoMascot: View {
    private let green = Color(red: 0.114, green: 0.620, blue: 0.459) // #1D9E75
    private let eye = Color(red: 0.039, green: 0.102, blue: 0.078)   // #0a1a14

    var body: some View {
        Canvas { context, size in
            let px = min(size.width / 16.0, size.height / 16.0)

            func fill(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: Color) {
                context.fill(
                    Path(CGRect(x: x * px, y: y * px, width: w * px, height: h * px)),
                    with: .color(color)
                )
            }

            // Head top
            fill(7, 2, 2, 2, green)
            // Head band
            fill(4, 4, 8, 2, green)
            // Face
            fill(3, 6, 10, 5, green)
            // Eyes
            fill(5, 7, 2, 2, eye)
            fill(9, 7, 2, 2, eye)
            // Feet
            fill(4, 11, 2, 2, green)
            fill(10, 11, 2, 2, green)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
