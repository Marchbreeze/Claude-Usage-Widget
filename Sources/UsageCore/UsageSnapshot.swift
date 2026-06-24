import Foundation

/// Which service the snapshot describes. Drives icon + accent color in the UI.
public enum ProviderKind: String, Codable, Equatable {
    case claude
    case copilot
}

/// GitHub Copilot premium-request quota (from /copilot_internal/user).
public struct CopilotDetail: Codable, Equatable {
    public let plan: String?
    /// Premium requests used, as a percent of entitlement (0 when unlimited).
    public let premiumPercent: Double
    public let remaining: Double?
    public let entitlement: Double?
    public let unlimited: Bool
    public let overageCount: Double?
    public let overageEntitlement: Double?
    public let overagePermitted: Bool
    public let resetsAt: Date?
    /// Overage spend in USD (overageCount × per-request price), filled in by the
    /// provider once the included quota is exhausted; nil otherwise.
    public let overageSpendUSD: Double?
    /// User-configured additional-usage budget in USD (the $ cap).
    public let overageBudgetUSD: Double?
    public init(plan: String?, premiumPercent: Double, remaining: Double?, entitlement: Double?, unlimited: Bool, overageCount: Double?, overageEntitlement: Double? = nil, overagePermitted: Bool, resetsAt: Date?, overageSpendUSD: Double? = nil, overageBudgetUSD: Double? = nil) {
        self.plan = plan
        self.premiumPercent = premiumPercent
        self.remaining = remaining
        self.entitlement = entitlement
        self.unlimited = unlimited
        self.overageCount = overageCount
        self.overageEntitlement = overageEntitlement
        self.overagePermitted = overagePermitted
        self.resetsAt = resetsAt
        self.overageSpendUSD = overageSpendUSD
        self.overageBudgetUSD = overageBudgetUSD
    }

    /// True once the included quota is spent and paid overage is active.
    public var isInOverage: Bool { overageSpendUSD != nil }
}

public struct ExtraUsage: Codable, Equatable {
    public let percent: Double
    public let usedUSD: Double?
    public let limitUSD: Double?
    public let resetsAt: Date?
    public init(percent: Double, usedUSD: Double?, limitUSD: Double?, resetsAt: Date? = nil) {
        self.percent = percent
        self.usedUSD = usedUSD
        self.limitUSD = limitUSD
        self.resetsAt = resetsAt
    }
}

public struct SubscriptionDetail: Codable, Equatable {
    public let fiveHourPercent: Double?
    public let fiveHourResetsAt: Date?
    public let sevenDayPercent: Double?
    public let sevenDayResetsAt: Date?
    public let extraUsage: ExtraUsage?
    public init(fiveHourPercent: Double?, fiveHourResetsAt: Date?, sevenDayPercent: Double?, sevenDayResetsAt: Date?, extraUsage: ExtraUsage? = nil) {
        self.fiveHourPercent = fiveHourPercent
        self.fiveHourResetsAt = fiveHourResetsAt
        self.sevenDayPercent = sevenDayPercent
        self.sevenDayResetsAt = sevenDayResetsAt
        self.extraUsage = extraUsage
    }
}

public struct UsageSnapshot: Codable, Equatable {
    public let percent: Double
    public let provider: ProviderKind
    public let subscription: SubscriptionDetail?
    public let copilot: CopilotDetail?
    public let fetchedAt: Date
    public init(percent: Double, provider: ProviderKind = .claude, subscription: SubscriptionDetail? = nil, copilot: CopilotDetail? = nil, fetchedAt: Date) {
        self.percent = percent
        self.provider = provider
        self.subscription = subscription
        self.copilot = copilot
        self.fetchedAt = fetchedAt
    }

    // Backward-compatible decoding: older cached snapshots have no `provider`/`copilot`.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        percent = try c.decode(Double.self, forKey: .percent)
        provider = try c.decodeIfPresent(ProviderKind.self, forKey: .provider) ?? .claude
        subscription = try c.decodeIfPresent(SubscriptionDetail.self, forKey: .subscription)
        copilot = try c.decodeIfPresent(CopilotDetail.self, forKey: .copilot)
        fetchedAt = try c.decode(Date.self, forKey: .fetchedAt)
    }
}
