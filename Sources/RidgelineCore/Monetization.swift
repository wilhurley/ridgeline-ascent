/// Ad formats that exist in Ridgeline Ascent.
///
/// Hard rule: there is no interstitial, pop-up, app-open, or mid-run banner.
/// Banners are allowed only on `BannerSurface` (the title screen and the results screen).
/// Rewarded placements are opt-in and once per run: revive, and double rewards.
public enum BannerSurface: String, Equatable, CaseIterable, Identifiable {
    case title
    case results

    public var id: String { rawValue }
}

public enum RewardedPlacement: String, Equatable, CaseIterable, Identifiable {
    case revive
    case doubleRewards

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .revive: return "Flare Revive"
        case .doubleRewards: return "Double Embers"
        }
    }
}

public enum RewardedAdResult: Equatable {
    case earned
    case dismissed
    case unavailable
}

public protocol RewardedAdServing: AnyObject {
    func show(placement: RewardedPlacement, completion: @escaping (RewardedAdResult) -> Void)
}

/// Summit Pack is the only planned purchase. It removes banners. It does not grant Embers.
public enum SummitPack {
    public static let productID = "com.ridgelineapps.ridgelineascent.summitpack"
    public static let displayName = "Summit Pack"
    public static let displayPrice = "$3.99"
    public static let summary = "Removes the banner slot from the trailhead and the results screen."
}

public enum PurchaseOutcome: Equatable {
    case owned
    case cancelled
    case unavailable
}

public protocol SummitPackPurchasing: AnyObject {
    var ownsSummitPack: Bool { get }
    func purchase() -> PurchaseOutcome
    func restore() -> PurchaseOutcome
}

public struct RunMonetizationState: Equatable {
    public var ownsSummitPack: Bool
    public internal(set) var reviveUsed: Bool
    public internal(set) var doubleRewardsUsed: Bool

    public init(ownsSummitPack: Bool, reviveUsed: Bool = false, doubleRewardsUsed: Bool = false) {
        self.ownsSummitPack = ownsSummitPack
        self.reviveUsed = reviveUsed
        self.doubleRewardsUsed = doubleRewardsUsed
    }

    public func showsBanner(on surface: BannerSurface) -> Bool {
        switch surface {
        case .title, .results:
            return !ownsSummitPack
        }
    }

    public var canOfferRevive: Bool { !reviveUsed }
    public var canOfferDoubleRewards: Bool { !doubleRewardsUsed }
}

public enum ReviveOutcome: Equatable {
    case revived
    case unavailable
    case notDefeated
    case adDeclined
    case adUnavailable
}

public enum DoubleRewardOutcome: Equatable {
    case doubled(extraEmbers: Int)
    case unavailable
    case runStillActive
    case adDeclined
    case adUnavailable
}
