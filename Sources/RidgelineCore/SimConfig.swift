import Foundation

/// Tunables for one ascent. Tests build short, deadly, or harmless variants.
/// `standard` is the playable 3–4 minute ridge.
public struct SimConfig: Equatable {
    public var seed: UInt64
    public var ridgeWidth: Double
    public var climberRadius: Double
    public var baseClimbSpeed: Double
    public var lateralSpeed: Double
    public var baseAttackDamage: Double
    public var baseAttackCooldown: Double
    public var baseAttackRange: Double
    public var baseMaxHealth: Double
    public var startingLead: Double
    public var minLead: Double
    public var pressureWindow: Double
    public var stageDurations: [Double]
    public var cairnInterval: Double
    public var bossHealth: Double
    public var bossLeash: Double
    public var bossCloseSpeed: Double
    public var spawnAhead: Double
    public var hitInvulnerability: Double
    /// Added on top of max health. Equal to one Scree Approach boulder hit.
    public var openingHealthBonus: Double
    public var hitSlowDuration: Double
    public var hitSlowMultiplier: Double
    public var spawnsEnabled: Bool
    public var extraAvalancheSpeed: Double
    public var leadTrackGain: Double
    public var bonusArmor: Double
    public var bonusBurn: Double
    public var climberID: String
    public var forcedWeather: WeatherKind?

    public init(
        seed: UInt64 = 1,
        ridgeWidth: Double = 320,
        climberRadius: Double = 12,
        baseClimbSpeed: Double = 78,
        lateralSpeed: Double = 240,
        baseAttackDamage: Double = 16,
        baseAttackCooldown: Double = 0.40,
        baseAttackRange: Double = 96,
        baseMaxHealth: Double = 100,
        startingLead: Double = 180,
        minLead: Double = 88,
        pressureWindow: Double = 210,
        stageDurations: [Double] = [70, 70, 70],
        cairnInterval: Double = 36,
        bossHealth: Double = 240,
        bossLeash: Double = 42,
        bossCloseSpeed: Double = 4.0,
        spawnAhead: Double = 320,
        hitInvulnerability: Double = 0.55,
        openingHealthBonus: Double = 12,
        hitSlowDuration: Double = 0.75,
        hitSlowMultiplier: Double = 0.45,
        spawnsEnabled: Bool = true,
        extraAvalancheSpeed: Double = 0,
        leadTrackGain: Double = 1.15,
        bonusArmor: Double = 0,
        bonusBurn: Double = 0,
        climberID: String = ClimberRoster.guide.id,
        forcedWeather: WeatherKind? = nil
    ) {
        self.seed = seed
        self.ridgeWidth = ridgeWidth
        self.climberRadius = climberRadius
        self.baseClimbSpeed = baseClimbSpeed
        self.lateralSpeed = lateralSpeed
        self.baseAttackDamage = baseAttackDamage
        self.baseAttackCooldown = baseAttackCooldown
        self.baseAttackRange = baseAttackRange
        self.baseMaxHealth = baseMaxHealth
        self.startingLead = startingLead
        self.minLead = minLead
        self.pressureWindow = pressureWindow
        self.stageDurations = stageDurations
        self.cairnInterval = cairnInterval
        self.bossHealth = bossHealth
        self.bossLeash = bossLeash
        self.bossCloseSpeed = bossCloseSpeed
        self.spawnAhead = spawnAhead
        self.hitInvulnerability = hitInvulnerability
        self.openingHealthBonus = openingHealthBonus
        self.hitSlowDuration = hitSlowDuration
        self.hitSlowMultiplier = hitSlowMultiplier
        self.spawnsEnabled = spawnsEnabled
        self.extraAvalancheSpeed = extraAvalancheSpeed
        self.leadTrackGain = leadTrackGain
        self.bonusArmor = bonusArmor
        self.bonusBurn = bonusBurn
        self.climberID = climberID
        self.forcedWeather = forcedWeather
    }

    public static var standard: SimConfig { SimConfig() }

    /// Painted body width. The collision circle is smaller than this so a graze on the coat misses.
    public static let presentedClimberRadius: Double = 14

    var durations: [Double] {
        if stageDurations.count >= 3 {
            return Array(stageDurations.prefix(3))
        }
        return stageDurations + Array(repeating: 70, count: 3 - stageDurations.count)
    }
}
