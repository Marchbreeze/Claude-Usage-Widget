import SwiftUI

/// Simplified GitHub Copilot mascot (rounded head + antenna + side "ears",
/// with two eyes cut out), tinted by a single color to match the menu bar style.
struct CopilotIconView: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: y * h) }
            func r(_ x: CGFloat, _ y: CGFloat, _ rw: CGFloat, _ rh: CGFloat) -> CGRect {
                CGRect(x: x * w, y: y * h, width: rw * w, height: rh * h)
            }

            var path = Path()
            // Antenna stalk + tip.
            path.addRect(CGRect(x: 0.475 * w, y: 0.02 * h, width: 0.05 * w, height: 0.13 * h))
            path.addEllipse(in: r(0.44, 0.0, 0.12, 0.10))
            // Side ears.
            path.addRoundedRect(in: r(0.0, 0.40, 0.14, 0.24), cornerSize: p(0.05, 0.05))
            path.addRoundedRect(in: r(0.86, 0.40, 0.14, 0.24), cornerSize: p(0.05, 0.05))
            // Head.
            path.addRoundedRect(in: r(0.12, 0.20, 0.76, 0.66), cornerSize: p(0.20, 0.20))
            // Eyes (cut out via even-odd fill).
            path.addEllipse(in: r(0.30, 0.42, 0.13, 0.22))
            path.addEllipse(in: r(0.57, 0.42, 0.13, 0.22))

            context.fill(path, with: .color(color), style: FillStyle(eoFill: true))
        }
        .accessibilityLabel("Copilot usage")
    }
}
