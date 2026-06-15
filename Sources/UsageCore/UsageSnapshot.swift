import Foundation

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
    public let subscription: SubscriptionDetail?
    public let fetchedAt: Date
    public init(percent: Double, subscription: SubscriptionDetail?, fetchedAt: Date) {
        self.percent = percent
        self.subscription = subscription
        self.fetchedAt = fetchedAt
    }
}
