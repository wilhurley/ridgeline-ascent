import Foundation

/// End-of-run tally. Embers are derived from points; they are never sold.
public struct RunScore: Equatable {
    public var altitude: Double
    public var hazardsDefeated: Int
    public var cairnsClaimed: Int
    public var stagesCleared: Int
    public var summitReached: Bool

    public init(
        altitude: Double = 0,
        hazardsDefeated: Int = 0,
        cairnsClaimed: Int = 0,
        stagesCleared: Int = 0,
        summitReached: Bool = false
    ) {
        self.altitude = altitude
        self.hazardsDefeated = hazardsDefeated
        self.cairnsClaimed = cairnsClaimed
        self.stagesCleared = stagesCleared
        self.summitReached = summitReached
    }

    public var points: Int {
        Int(altitude.rounded(.down))
            + hazardsDefeated * 25
            + cairnsClaimed * 40
            + stagesCleared * 150
            + (summitReached ? 500 : 0)
    }

    /// Embers before charm yield. Summit adds a flat bonus on top of the point conversion.
    public var embers: Int {
        points / 250 + (summitReached ? 20 : 0)
    }

    public func earnedEmbers(yieldFraction: Double) -> Int {
        let scaled = Double(embers) * (1 + max(0, yieldFraction))
        return Int(scaled.rounded(.down))
    }

    public var ridgeEmbers: Int { points / 250 }

    public var summitBonus: Int { summitReached ? 20 : 0 }

    public func emberBreakdown(yieldFraction: Double) -> EmberBreakdown {
        let total = earnedEmbers(yieldFraction: yieldFraction)
        return EmberBreakdown(
            fromRidge: ridgeEmbers,
            summitBonus: summitBonus,
            charmYield: total - ridgeEmbers - summitBonus,
            total: total
        )
    }
}

public struct EmberBreakdown: Equatable {
    public let fromRidge: Int
    public let summitBonus: Int
    public let charmYield: Int
    public let total: Int
}

public enum RunEnd: Equatable {
    case summit
    case defeat(DefeatCause)

    public var headline: String {
        switch self {
        case .summit:
            return "The summit holds."
        case .defeat(let cause):
            return cause.epitaph
        }
    }
}

public struct RunSummary: Equatable {
    public let score: RunScore
    public let embersEarned: Int
    public let end: RunEnd
    public let charmNames: [String]
    public let fusionNames: [String]
    public let setBonusNames: [String]
    public let daily: Bool
    public let elapsed: TimeInterval
    public let stageName: String
    public let emberBreakdown: EmberBreakdown
    public let charmIDs: [String]

    public init(
        score: RunScore,
        embersEarned: Int,
        end: RunEnd,
        charmNames: [String],
        fusionNames: [String],
        setBonusNames: [String],
        daily: Bool,
        elapsed: TimeInterval,
        stageName: String,
        emberBreakdown: EmberBreakdown,
        charmIDs: [String]
    ) {
        self.score = score
        self.embersEarned = embersEarned
        self.end = end
        self.charmNames = charmNames
        self.fusionNames = fusionNames
        self.setBonusNames = setBonusNames
        self.daily = daily
        self.elapsed = elapsed
        self.stageName = stageName
        self.emberBreakdown = emberBreakdown
        self.charmIDs = charmIDs
    }
}
