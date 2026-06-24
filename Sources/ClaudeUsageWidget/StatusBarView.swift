import SwiftUI
import UsageCore

struct StatusBarModel {
    var percent: Double?
    var provider: ProviderKind = .claude
    var isStale: Bool = false
}

struct StatusBarView: View {
    let model: StatusBarModel

    // Over-threshold red is shared; the base accent depends on the provider:
    // Claude orange (#D97757) vs GitHub accent blue (#0969DA).
    private var color: Color {
        guard let p = model.percent else { return .gray }
        if PercentMath.isOverThreshold(p) { return Color(red: 0.898, green: 0.282, blue: 0.302) }
        switch model.provider {
        case .claude: return Color(red: 0.851, green: 0.467, blue: 0.341)
        case .copilot: return Color(red: 0.035, green: 0.412, blue: 0.855)
        }
    }

    @ViewBuilder private var icon: some View {
        switch model.provider {
        case .claude: ClaudeIconView(color: color)
        case .copilot: CopilotIconView(color: color)
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            icon.frame(width: 15, height: 15)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.25))
                    Capsule().fill(color)
                        .frame(width: geo.size.width * CGFloat((model.percent ?? 0) / 100))
                }
            }
            .frame(width: 48, height: 6)
            Text(model.percent.map { "\(Int($0.rounded()))%" } ?? "—")
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundColor(color)
                .opacity(model.isStale ? 0.55 : 1)
        }
        .padding(.horizontal, 6)
        .frame(height: 22)
    }
}
