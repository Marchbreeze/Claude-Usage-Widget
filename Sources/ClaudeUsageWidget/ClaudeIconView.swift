import SwiftUI

struct ClaudeIconView: View {
    let color: Color

    private static let solidRects: [CGRect] = [
        CGRect(x: 0.14, y: 0.18, width: 0.72, height: 0.48),
        CGRect(x: 0.00, y: 0.43, width: 0.14, height: 0.10),
        CGRect(x: 0.86, y: 0.43, width: 0.14, height: 0.10),
        CGRect(x: 0.208, y: 0.66, width: 0.13, height: 0.10),
        CGRect(x: 0.637, y: 0.66, width: 0.13, height: 0.10),
    ]

    private static let eyeRects: [CGRect] = [
        CGRect(x: 0.248, y: 0.31, width: 0.05, height: 0.13),
        CGRect(x: 0.67, y: 0.31, width: 0.05, height: 0.13),
    ]

    var body: some View {
        Canvas { context, size in
            var path = Path()
            for rect in Self.solidRects { path.addRect(scaled(rect, in: size)) }
            for rect in Self.eyeRects { path.addRect(scaled(rect, in: size)) }
            context.fill(path, with: .color(color), style: FillStyle(eoFill: true))
        }
        .accessibilityLabel("Claude usage")
    }

    private func scaled(_ rect: CGRect, in size: CGSize) -> CGRect {
        CGRect(
            x: rect.minX * size.width,
            y: rect.minY * size.height,
            width: rect.width * size.width,
            height: rect.height * size.height
        )
    }
}
