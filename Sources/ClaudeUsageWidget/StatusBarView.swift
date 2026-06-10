import SwiftUI
import UsageCore

struct StatusBarModel {
    var percent: Double?
    var isStale: Bool = false
}

struct StatusBarView: View {
    let model: StatusBarModel

    private var color: Color {
        guard let p = model.percent else { return .gray }
        if PercentMath.isOverThreshold(p) { return Color(red: 0.898, green: 0.282, blue: 0.302) }
        return Color(red: 0.851, green: 0.467, blue: 0.341)
    }

    var body: some View {
        HStack(spacing: 5) {
            ClaudeIconView(color: color).frame(width: 15, height: 15)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.25))
                    Capsule().fill(color)
                        .frame(width: geo.size.width * CGFloat((model.percent ?? 0) / 100))
                }
            }
            .frame(width: 36, height: 6)
            Text(model.percent.map { "\(Int($0.rounded()))%" } ?? "—")
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundColor(color)
                .opacity(model.isStale ? 0.55 : 1)
        }
        .padding(.horizontal, 6)
        .frame(height: 22)
    }
}
