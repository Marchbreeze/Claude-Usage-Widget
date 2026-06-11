import SwiftUI

struct ClaudeIconView: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            var path = Path()

            let bodyLeft = 0.08 * w
            let bodyRight = 0.92 * w
            let domeCenterY = 0.52 * h
            let footTopY = 0.82 * h
            let radius = (bodyRight - bodyLeft) / 2

            path.move(to: CGPoint(x: bodyLeft, y: domeCenterY))
            path.addArc(
                center: CGPoint(x: 0.5 * w, y: domeCenterY),
                radius: radius,
                startAngle: .degrees(180),
                endAngle: .degrees(0),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: bodyRight, y: footTopY))

            let legCount = 4
            let legWidth = (bodyRight - bodyLeft) / CGFloat(legCount)
            for i in 0..<legCount {
                let centerX = bodyRight - (CGFloat(i) + 0.5) * legWidth
                path.addArc(
                    center: CGPoint(x: centerX, y: footTopY),
                    radius: legWidth / 2,
                    startAngle: .degrees(0),
                    endAngle: .degrees(180),
                    clockwise: false
                )
            }

            path.closeSubpath()

            let eyeRadius = 0.07 * w
            for eyeX in [0.34 * w, 0.66 * w] {
                path.addEllipse(in: CGRect(
                    x: eyeX - eyeRadius,
                    y: 0.48 * h - eyeRadius,
                    width: eyeRadius * 2,
                    height: eyeRadius * 2
                ))
            }

            context.fill(path, with: .color(color), style: FillStyle(eoFill: true))
        }
        .accessibilityLabel("Claude usage")
    }
}
