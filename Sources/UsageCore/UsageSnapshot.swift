import Foundation

public struct ExtraUsage: Codable, Equatable {
    public let percent: Double
    public let usedUSD: Double?
    public let limitUSD: Double?
    public init(percent: Double, usedUSD: Double?, limitUSD: Double?) {
        self.percent = percent
        self.usedUSD = usedUSD
        self.limitUSD = limitUSD
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

public struct APIDetail: Codable, Equatable {
    public let spendUSD: Double
    public let budgetUSD: Double
    public init(spendUSD: Double, budgetUSD: Double) {
        self.spendUSD = spendUSD
        self.budgetUSD = budgetUSD
    }
}

public struct UsageSnapshot: Codable, Equatable {
    public enum Source: String, Codable { case subscription, api }
    public let source: Source
    public let percent: Double
    public let subscription: SubscriptionDetail?
    public let api: APIDetail?
    public let fetchedAt: Date
    public init(source: Source, percent: Double, subscription: SubscriptionDetail?, api: APIDetail?, fetchedAt: Date) {
        self.source = source
        self.percent = percent
        self.subscription = subscription
        self.api = api
        self.fetchedAt = fetchedAt
    }
}
