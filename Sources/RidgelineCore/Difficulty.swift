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
    case pebble
    case boulder
    case slab
    case iceWraith
    case stormCrow
    case corniceTyrant

    public var id: String { rawValue }

    public var isRock: Bool {
        switch self {
        case .pebble, .boulder, .slab:
            return true
        case .iceWraith, .stormCrow, .corniceTyrant:
            return false
        }
    }

    public var displayName: String {
        switch self {
        case .pebble: return "Pebble"
        case .boulder: return "Boulder"
        case .slab: return "Slab"
        case .iceWraith: return "Ice Wraith"
        case .stormCrow: return "Storm Crow"
        case .corniceTyrant: return "Cornice Tyrant"
        }
    }
}

public struct SpawnWeight: Equatable {
    public var kind: HazardKind
    public var weight: Int

    public init(kind: HazardKind, weight: Int) {
        self.kind = kind
        self.weight = weight
    }
}

public struct DifficultySample: Equatable {
    public var spawnInterval: Double
    public var hazardSpeed: Double
    public var hazardHealth: Double
    public var contactDamage: Double
    public var avalancheBonus: Double
    public var weights: [SpawnWeight]

    public var allowedKinds: [HazardKind] {
        weights.map(\.kind)
    }
}

/// Stage 1 opens quieter, then meets the regular curve by the end of that stage.
/// Later stages are unchanged. The spawn scale is chosen so a linear ramp
/// removes about a quarter of the rocks across the first stage.
public enum OpeningEase {
    public static let window: Double = 70
    public static let spawnIntervalScale: Double = 1.86
    public static let fallSpeedScale: Double = 0.76
    public static let telegraphBonus: Double = 0.2

    /// 1 at the start of Scree Approach, 0 once `window` seconds have passed, and 0 on later stages.
    public static func blend(stage: StageID, timeInStage: Double) -> Double {
        guard stage == .screeApproach else { return 0 }
        let t = min(max(timeInStage, 0), window)
        return 1 - t / window
    }

    public static func spawnScale(stage: StageID, timeInStage: Double) -> Double {
        1 + (spawnIntervalScale - 1) * blend(stage: stage, timeInStage: timeInStage)
    }

    public static func fallScale(stage: StageID, timeInStage: Double) -> Double {
        1 - (1 - fallSpeedScale) * blend(stage: stage, timeInStage: timeInStage)
    }

    public static func telegraphLead(base: Double, stage: StageID, timeInStage: Double) -> Double {
        base + telegraphBonus * blend(stage: stage, timeInStage: timeInStage)
    }
}

public enum DifficultyCurve {
    /// Spawn pace, hazard toughness, and an avalanche-speed bonus.
    /// `timeInStage` is seconds since the current stage began.
    /// `climbTime` is seconds of active climbing and boss time, excluding cairn pauses.
    public static func sample(stage: StageID, timeInStage: Double, climbTime: Double) -> DifficultySample {
        let index = Double(stage.rawValue)
        let stageRamp = min(max(timeInStage, 0), 80)
        let spawnInterval: Double
        let weights: [SpawnWeight]
        switch stage {
        case .screeApproach:
            spawnInterval = max(0.55, 1.28 - stageRamp * 0.006)
            weights = [
                SpawnWeight(kind: .pebble, weight: 5),
                SpawnWeight(kind: .boulder, weight: 2)
            ]
        case .iceShelf:
            spawnInterval = max(0.48, 1.05 - stageRamp * 0.005)
            weights = [
                SpawnWeight(kind: .pebble, weight: 3),
                SpawnWeight(kind: .boulder, weight: 3),
                SpawnWeight(kind: .slab, weight: 2),
                SpawnWeight(kind: .iceWraith, weight: 3)
            ]
        case .crowsEave:
            spawnInterval = max(0.40, 0.92 - stageRamp * 0.004)
            weights = [
                SpawnWeight(kind: .pebble, weight: 2),
                SpawnWeight(kind: .boulder, weight: 3),
                SpawnWeight(kind: .slab, weight: 2),
                SpawnWeight(kind: .iceWraith, weight: 2),
                SpawnWeight(kind: .stormCrow, weight: 3)
            ]
        case .theCornice:
            spawnInterval = max(0.90, 1.45 - stageRamp * 0.003)
            weights = [
                SpawnWeight(kind: .pebble, weight: 3),
                SpawnWeight(kind: .boulder, weight: 1),
                SpawnWeight(kind: .stormCrow, weight: 2)
            ]
        }
        let spawnScale = OpeningEase.spawnScale(stage: stage, timeInStage: timeInStage)
        return DifficultySample(
            spawnInterval: spawnInterval * spawnScale,
            hazardSpeed: (120 + 24 * (index - 1)) * OpeningEase.fallScale(stage: stage, timeInStage: timeInStage),
            hazardHealth: 18 + 8 * (index - 1),
            contactDamage: 12 + 4 * (index - 1),
            avalancheBonus: 5 * (index - 1) + 0.015 * max(0, climbTime),
            weights: weights
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
