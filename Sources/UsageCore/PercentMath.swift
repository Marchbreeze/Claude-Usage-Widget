import Foundation

public enum PercentMath {
    public static func clamp(_ p: Double) -> Double { min(100, max(0, p)) }
    public static func budgetPercent(spend: Double, budget: Double) -> Double? {
        guard budget > 0 else { return nil }
        return clamp(spend / budget * 100)
    }
    public static func isOverThreshold(_ percent: Double) -> Bool { percent > 80 }
}
