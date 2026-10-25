import Foundation

/// Which body the scene draws. Gameplay numbers live on `ClimberProfile`.
/// A future sprite sheet can key off this id without changing the rules.
public enum ClimberPortrait: String, Codable, Equatable, CaseIterable {
    case guide
    case scout
    case hauler
}

/// A starting climber. Stat differences are paid for with earned Embers, never with a purchase.
public struct ClimberProfile: Equatable, Identifiable, Codable {
    public let id: String
    public let name: String
    public let epithet: String
    public let summary: String
    public let portrait: ClimberPortrait
    public let toolName: String
    public let gearStyle: GearStyle
    public let climbMultiplier: Double
    public let healthMultiplier: Double
    public let damageMultiplier: Double
    public let cooldownMultiplier: Double
    public let bonusArmor: Double
    public let bonusBurn: Double
    public let unlockCost: Int

    public var idString: String { id }
}

/// Coat and color only. `isCosmeticOnly` is always true: a skin must not change speed, health, or damage.
public struct ClimberSkin: Equatable, Identifiable, Codable {
    public let id: String
    public let climberID: String
    public let name: String
    /// Set when a later StoreKit product should unlock the coat. Nil means it is included.
    public let productID: String?

    public var isCosmeticOnly: Bool { true }
}

public enum ClimberRoster {
    public static let guide = ClimberProfile(
        id: "guide",
        name: "Sera Quinn",
        epithet: "Ridge Guide",
        summary: "Even pace, an ice axe, and a coat you can trust.",
        portrait: .guide,
        toolName: "Ice axe",
        gearStyle: .iceAxe,
        climbMultiplier: 1,
        healthMultiplier: 1,
        damageMultiplier: 1,
        cooldownMultiplier: 1,
        bonusArmor: 0,
        bonusBurn: 0,
        unlockCost: 0
    )

    public static let scout = ClimberProfile(
        id: "scout",
        name: "Pell Ash",
        epithet: "Storm Scout",
        summary: "Fast on the shale and light on the ribs. The flare is already lit.",
        portrait: .scout,
        toolName: "Flare",
        gearStyle: .flare,
        climbMultiplier: 1.18,
        healthMultiplier: 0.72,
        damageMultiplier: 0.88,
        cooldownMultiplier: 0.84,
        bonusArmor: 0,
        bonusBurn: 3,
        unlockCost: 30
    )

    public static let hauler = ClimberProfile(
        id: "hauler",
        name: "Bram Holt",
        epithet: "Scree Hauler",
        summary: "Slow boots, a thick coat, and a hammer-axe that hits harder.",
        portrait: .hauler,
        toolName: "Hammer-axe",
        gearStyle: .iceAxe,
        climbMultiplier: 0.84,
        healthMultiplier: 1.45,
        damageMultiplier: 1.16,
        cooldownMultiplier: 1.20,
        bonusArmor: 0.08,
        bonusBurn: 0,
        unlockCost: 50
    )

    public static let all: [ClimberProfile] = [guide, scout, hauler]

    public static let highCampCoatID = "high-camp-coat"

    public static let skins: [ClimberSkin] = [
        ClimberSkin(id: "sera-camp", climberID: guide.id, name: "Camp orange", productID: nil),
        ClimberSkin(id: "pell-camp", climberID: scout.id, name: "Teal windbreaker", productID: nil),
        ClimberSkin(id: "bram-camp", climberID: hauler.id, name: "Hauler brown", productID: nil),
        ClimberSkin(
            id: highCampCoatID,
            climberID: guide.id,
            name: "High-camp coat",
            productID: "com.ridgelineapps.ridgelineascent.skin.highcamp"
        )
    ]

    public static func profile(id: String) -> ClimberProfile {
        all.first { $0.id == id } ?? guide
    }

    public static func includedSkin(for climberID: String) -> ClimberSkin? {
        skins.first { $0.climberID == climberID && $0.productID == nil }
    }

    /// Copies the config and applies this climber's numbers. Skins are not an argument: they cannot change the climb.
    public static func applying(_ profile: ClimberProfile, to config: SimConfig) -> SimConfig {
        var config = config
        config.baseClimbSpeed *= profile.climbMultiplier
        config.baseMaxHealth *= profile.healthMultiplier
        config.baseAttackDamage *= profile.damageMultiplier
        config.baseAttackCooldown *= profile.cooldownMultiplier
        config.bonusArmor = profile.bonusArmor
        config.bonusBurn = profile.bonusBurn
        config.climberID = profile.id
        return config
    }

    public static func affectsRules(_ skin: ClimberSkin) -> Bool {
        _ = skin
        return false
    }
}

public struct ClimberLocker: Equatable, Codable {
    public var unlockedIDs: Set<String>
    public var selectedID: String
    public var selectedSkinID: String?
    public var ownedCosmeticIDs: Set<String>

    public init(
        unlockedIDs: Set<String> = [ClimberRoster.guide.id],
        selectedID: String = ClimberRoster.guide.id,
        selectedSkinID: String? = ClimberRoster.includedSkin(for: ClimberRoster.guide.id)?.id,
        ownedCosmeticIDs: Set<String> = []
    ) {
        self.unlockedIDs = unlockedIDs
        self.selectedID = selectedID
        self.selectedSkinID = selectedSkinID
        self.ownedCosmeticIDs = ownedCosmeticIDs
    }

    public static var fresh: ClimberLocker { ClimberLocker() }

    public func isUnlocked(_ id: String) -> Bool {
        unlockedIDs.contains(id)
    }

    public enum UnlockResult: Equatable {
        case unlocked
        case alreadyOwned
        case cannotAfford
        case unknown
    }

    @discardableResult
    public mutating func select(_ id: String) -> Bool {
        guard ClimberRoster.all.contains(where: { $0.id == id }), isUnlocked(id) else { return false }
        selectedID = id
        if let skin = ClimberRoster.includedSkin(for: id) {
            selectedSkinID = skin.id
        }
        return true
    }

    @discardableResult
    public mutating func unlock(_ id: String, wallet: EmbersWallet) -> UnlockResult {
        guard let profile = ClimberRoster.all.first(where: { $0.id == id }) else { return .unknown }
        if unlockedIDs.contains(id) { return .alreadyOwned }
        if profile.unlockCost > 0 {
            guard wallet.debit(profile.unlockCost) else { return .cannotAfford }
        }
        unlockedIDs.insert(id)
        return .unlocked
    }

    /// Records a coat. Does not credit or debit Embers and does not change a profile's numbers.
    @discardableResult
    public mutating func grantCosmetic(_ id: String) -> Bool {
        guard let skin = ClimberRoster.skins.first(where: { $0.id == id }), skin.isCosmeticOnly else { return false }
        ownedCosmeticIDs.insert(id)
        return true
    }

    @discardableResult
    public mutating func equip(_ skinID: String) -> Bool {
        guard let skin = ClimberRoster.skins.first(where: { $0.id == skinID }) else { return false }
        guard isUnlocked(skin.climberID) else { return false }
        if skin.productID != nil && !ownedCosmeticIDs.contains(skin.id) {
            return false
        }
        selectedID = skin.climberID
        selectedSkinID = skin.id
        return true
    }
}
