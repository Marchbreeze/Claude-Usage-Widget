import SwiftUI

struct ClaudeIconView: View {
    let color: Color
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = min(size.width, size.height) / 2
            let inner = outer * 0.38
            let rayWidth = outer * 0.26
            for i in 0..<12 {
                let angle = Double(i) * .pi / 6
                var path = Path()
                let from = CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner)
                let to = CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer)
                path.move(to: from)
                path.addLine(to: to)
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: rayWidth, lineCap: .round))
            }
        }
        .accessibilityLabel("Claude usage")
    }
}
