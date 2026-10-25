import Foundation

public enum StageID: Int, Equatable, Codable, CaseIterable, Identifiable {
    case screeApproach = 1
    case iceShelf = 2
    case crowsEave = 3
    case theCornice = 4

    public var id: Int { rawValue }

    public var displayName: String {
        switch self {
        case .screeApproach: return "Scree Approach"
        case .iceShelf: return "Ice Shelf"
        case .crowsEave: return "Crow's Eave"
        case .theCornice: return "The Cornice"
        }
    }

    public var next: StageID? {
        StageID(rawValue: rawValue + 1)
    }
}

public enum HazardKind: String, Equatable, Codable, CaseIterable, Identifiable {
    case fallingRock
    case iceWraith
    case stormCrow
    case corniceTyrant

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .fallingRock: return "Falling Rock"
        case .iceWraith: return "Ice Wraith"
        case .stormCrow: return "Storm Crow"
        case .corniceTyrant: return "Cornice Tyrant"
        }
    }
}

public struct DifficultySample: Equatable {
    public var spawnInterval: Double
    public var hazardSpeed: Double
    public var hazardHealth: Double
    public var contactDamage: Double
    public var avalancheBonus: Double
    public var allowedKinds: [HazardKind]
}

public enum DifficultyCurve {
    /// Spawn pace, hazard toughness, and an avalanche-speed bonus.
    /// `timeInStage` is seconds since the current stage began.
    /// `climbTime` is seconds of active climbing and boss time, excluding cairn pauses.
    public static func sample(stage: StageID, timeInStage: Double, climbTime: Double) -> DifficultySample {
        let index = Double(stage.rawValue)
        let stageRamp = min(max(timeInStage, 0), 80)
        let spawnInterval: Double
        let kinds: [HazardKind]
        switch stage {
        case .screeApproach:
            spawnInterval = max(0.55, 1.28 - stageRamp * 0.006)
            kinds = [.fallingRock]
        case .iceShelf:
            spawnInterval = max(0.48, 1.05 - stageRamp * 0.005)
            kinds = [.fallingRock, .iceWraith]
        case .crowsEave:
            spawnInterval = max(0.40, 0.92 - stageRamp * 0.004)
            kinds = [.fallingRock, .iceWraith, .stormCrow]
        case .theCornice:
            spawnInterval = max(0.90, 1.45 - stageRamp * 0.003)
            kinds = [.fallingRock, .stormCrow]
        }
        return DifficultySample(
            spawnInterval: spawnInterval,
            hazardSpeed: 120 + 24 * (index - 1),
            hazardHealth: 18 + 8 * (index - 1),
            contactDamage: 12 + 4 * (index - 1),
            avalancheBonus: 5 * (index - 1) + 0.015 * max(0, climbTime),
            allowedKinds: kinds
        )
    }
}

/// Where the avalanche wants the gap to sit. Clean climbing tracks this gap.
/// Hits slow the climber without slowing the avalanche, so the gap collapses.
public enum Pressure {
    public static func targetLead(config: SimConfig, stage: StageID, climbTime: Double, bossTime: Double) -> Double {
        if stage == .theCornice {
            return max(0, 130 - max(0, bossTime) * config.bossCloseSpeed)
        }
        let window = max(config.pressureWindow, 1)
        let progress = min(1, max(0, climbTime / window))
        return config.startingLead + (config.minLead - config.startingLead) * progress
    }
}
