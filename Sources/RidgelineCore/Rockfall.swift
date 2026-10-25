import Foundation

public struct RockSpec: Equatable {
    public let kind: HazardKind
    public let speedMultiplier: Double
    public let health: Double
    public let radius: Double
    public let contactMultiplier: Double
    public let splitsInto: [HazardKind]
}

public enum Rockfall {
    public static func isRock(_ kind: HazardKind) -> Bool {
        kind.isRock
    }

    /// Numbers for a rock on a stage. Non-rocks return nil.
    public static func spec(_ kind: HazardKind, stage: StageID) -> RockSpec? {
        let step = Double(max(0, stage.rawValue - 1))
        switch kind {
        case .pebble:
            return RockSpec(
                kind: .pebble,
                speedMultiplier: 1.55,
                health: 13 + step * 2,
                radius: 7,
                contactMultiplier: 0.55,
                splitsInto: []
            )
        case .boulder:
            return RockSpec(
                kind: .boulder,
                speedMultiplier: 0.92,
                health: 34 + step * 6,
                radius: 14,
                contactMultiplier: 1,
                splitsInto: []
            )
        case .slab:
            return RockSpec(
                kind: .slab,
                speedMultiplier: 0.50,
                health: 64 + step * 10,
                radius: 27,
                contactMultiplier: 1.4,
                splitsInto: [.boulder, .pebble]
            )
        case .iceWraith, .stormCrow, .corniceTyrant:
            return nil
        }
    }
}
