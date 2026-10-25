import Foundation

/// One ascent plus the once-per-run reward hooks and the Embers payout.
/// Touch input and rendering stay outside this type.
public final class RunSession {
    public let daily: Bool
    public let simulation: RidgeSimulation
    public let wallet: EmbersWallet
    public private(set) var monetization: RunMonetizationState
    public private(set) var summary: RunSummary?
    public private(set) var embersGranted: Int = 0

    private let ads: RewardedAdServing
    private let leaderboards: LeaderboardSubmitting
    private var baseEmbers = 0

    public init(
        simulation: RidgeSimulation,
        daily: Bool,
        wallet: EmbersWallet,
        ownsSummitPack: Bool,
        ads: RewardedAdServing,
        leaderboards: LeaderboardSubmitting
    ) {
        self.simulation = simulation
        self.daily = daily
        self.wallet = wallet
        self.monetization = RunMonetizationState(ownsSummitPack: ownsSummitPack)
        self.ads = ads
        self.leaderboards = leaderboards
    }

    public var canOfferRevive: Bool {
        summary == nil && monetization.canOfferRevive && isDefeated
    }

    public var canOfferDoubleRewards: Bool {
        summary != nil && monetization.canOfferDoubleRewards
    }

    public var isDefeated: Bool {
        if case .defeated = simulation.phase { return true }
        return false
    }

    /// Credits Embers once when the ascent is over and queues a leaderboard score.
    @discardableResult
    public func settleIfNeeded() -> RunSummary? {
        if let summary { return summary }
        let end: RunEnd
        switch simulation.phase {
        case .summit:
            end = .summit
        case .defeated(let cause):
            end = .defeat(cause)
        case .climbing, .cairn, .boss:
            return nil
        }
        let earned = simulation.score.earnedEmbers(yieldFraction: simulation.loadout.emberYield)
        baseEmbers = earned
        embersGranted = earned
        wallet.credit(earned)
        let settled = RunSummary(
            score: simulation.score,
            embersEarned: earned,
            end: end,
            charmNames: simulation.ownedCharms.map(\.name),
            fusionNames: simulation.activeFusions.map(\.name),
            setBonusNames: simulation.activeSetBonuses.map(\.name),
            daily: daily,
            elapsed: simulation.elapsed,
            stageName: simulation.stage.displayName
        )
        summary = settled
        let board: LeaderboardID = daily ? .dailyAscent : .bestAltitude
        leaderboards.submit(score: simulation.score.points, leaderboard: board)
        return settled
    }

    public func requestRevive(completion: @escaping (ReviveOutcome) -> Void) {
        guard summary == nil else {
            completion(.unavailable)
            return
        }
        guard isDefeated else {
            completion(.notDefeated)
            return
        }
        guard monetization.canOfferRevive else {
            completion(.unavailable)
            return
        }
        ads.show(placement: .revive) { [weak self] result in
            guard let self else {
                completion(.unavailable)
                return
            }
            completion(self.applyRevive(result))
        }
    }

    public func requestDoubleRewards(completion: @escaping (DoubleRewardOutcome) -> Void) {
        guard summary != nil else {
            completion(.runStillActive)
            return
        }
        guard monetization.canOfferDoubleRewards else {
            completion(.unavailable)
            return
        }
        ads.show(placement: .doubleRewards) { [weak self] result in
            guard let self else {
                completion(.unavailable)
                return
            }
            completion(self.applyDouble(result))
        }
    }

    private func applyRevive(_ result: RewardedAdResult) -> ReviveOutcome {
        guard summary == nil, isDefeated, monetization.canOfferRevive else {
            return .unavailable
        }
        switch result {
        case .earned:
            monetization.reviveUsed = true
            simulation.revive()
            return .revived
        case .dismissed:
            return .adDeclined
        case .unavailable:
            return .adUnavailable
        }
    }

    private func applyDouble(_ result: RewardedAdResult) -> DoubleRewardOutcome {
        guard summary != nil else { return .runStillActive }
        guard monetization.canOfferDoubleRewards else { return .unavailable }
        switch result {
        case .earned:
            monetization.doubleRewardsUsed = true
            wallet.credit(baseEmbers)
            embersGranted += baseEmbers
            return .doubled(extraEmbers: baseEmbers)
        case .dismissed:
            return .adDeclined
        case .unavailable:
            return .adUnavailable
        }
    }
}
