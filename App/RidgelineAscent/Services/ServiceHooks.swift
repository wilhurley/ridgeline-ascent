import Foundation
import UIKit
import RidgelineCore

enum StorageKey {
    static let embers = "ridgeline.embers"
    static let summitPack = "ridgeline.summitPack.owned"
    static let bestAltitude = "ridgeline.bestAltitude"
    static let bestDaily = "ridgeline.bestDaily"
}

/// Drop-in point for a rewarded-ad SDK.
/// Only `RewardedPlacement` may be requested. Do not add an interstitial entry point.
final class PlaceholderRewardedAds: RewardedAdServing {
    var present: ((RewardedPlacement, @escaping (RewardedAdResult) -> Void) -> Void)?

    func show(placement: RewardedPlacement, completion: @escaping (RewardedAdResult) -> Void) {
        if let present {
            present(placement, completion)
        } else {
            completion(.unavailable)
        }
    }
}

/// Drop-in point for StoreKit 2.
/// `purchase()` should load `SummitPack.productID` and finish only a verified transaction.
/// This slice grants the entitlement locally so the banner can be removed in a playtest.
/// The pack never mints Embers.
final class SummitPackHook: SummitPackPurchasing {
    private let defaults: UserDefaults
    private(set) var ownsSummitPack: Bool

    init(defaults: UserDefaults) {
        self.defaults = defaults
        self.ownsSummitPack = defaults.bool(forKey: StorageKey.summitPack)
    }

    func purchase() -> PurchaseOutcome {
        ownsSummitPack = true
        defaults.set(true, forKey: StorageKey.summitPack)
        return .owned
    }

    func restore() -> PurchaseOutcome {
        ownsSummitPack ? .owned : .unavailable
    }
}

/// Drop-in point for GameKit.
/// Authenticate `GKLocalPlayer` and call `GKLeaderboard.submitScore` with `leaderboard.rawValue`.
final class GameCenterHook: LeaderboardSubmitting {
    private(set) var queued: [(score: Int, board: LeaderboardID)] = []
    private(set) var lastNote = "Game Center hook is ready. Sign-in is not linked yet."

    func submit(score: Int, leaderboard: LeaderboardID) {
        queued.append((score, leaderboard))
        lastNote = "Queued \(score) for \(leaderboard.displayName). Game Center sign-in is not linked yet."
    }
}

final class LocalBestStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    var bestAltitude: Int { defaults.integer(forKey: StorageKey.bestAltitude) }
    var bestDaily: Int { defaults.integer(forKey: StorageKey.bestDaily) }

    @discardableResult
    func record(altitude: Int, daily: Bool) -> Bool {
        var improved = false
        if altitude > bestAltitude {
            defaults.set(altitude, forKey: StorageKey.bestAltitude)
            improved = true
        }
        if daily && altitude > bestDaily {
            defaults.set(altitude, forKey: StorageKey.bestDaily)
            improved = true
        }
        return improved
    }
}

enum HapticCue {
    case cairn
    case charm
    case hurt
    case revive
    case summit
}

final class HapticHook {
    func play(_ cue: HapticCue) {
        switch cue {
        case .hurt:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .cairn, .charm:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .revive, .summit:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
