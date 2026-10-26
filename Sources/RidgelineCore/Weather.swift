import Foundation

/// One ridge weather. Rolled per stage from the run seed, so a daily ascent
/// is the same storm for everyone. Skins and purchases never change this.
public enum WeatherKind: String, Codable, Equatable, CaseIterable, Identifiable {
    case clear
    case rain
    case blizzard
    case nightStorm

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .clear: return "Clear"
        case .rain: return "Rain"
        case .blizzard: return "Blizzard"
        case .nightStorm: return "Night Storm"
        }
    }

    /// SF Symbol used by the callout and the field guide. The art is still drawn in code.
    public var symbolName: String {
        switch self {
        case .clear: return "sun.max"
        case .rain: return "cloud.rain"
        case .blizzard: return "wind.snow"
        case .nightStorm: return "cloud.bolt"
        }
    }
}

public struct WeatherDefinition: Equatable, Identifiable {
    public let kind: WeatherKind
    public let name: String
    public let summary: String
    /// World units above the climber that stay readable. Beyond this, rocks hide until lightning or they close in.
    public let viewDistance: Double
    /// 0 follows the finger. Higher keeps lateral speed after the finger stops.
    public let steerSlip: Double
    /// Sideways push, world units per second at the peak of a gust. 0 in still air.
    public let gustAmplitude: Double
    /// Seconds between lightning flashes. 0 means no lightning.
    public let lightningPeriod: Double
    public let lightningDuration: Double
    /// Extra multiplier added to charm, set-bonus, and fusion numbers of that tag. 0.25 means +25%.
    public let tagBoosts: [ElementTag: Double]
    public let telegraphsRocks: Bool
    public let warningLead: Double

    public var id: WeatherKind { kind }

    public var boostedTags: [ElementTag] {
        tagBoosts.filter { $0.value > 0 }.map(\.key).sorted { $0.rawValue < $1.rawValue }
    }
}

public enum WeatherTable {
    public static func definition(for kind: WeatherKind) -> WeatherDefinition {
        switch kind {
        case .clear:
            return WeatherDefinition(
                kind: .clear,
                name: "Clear",
                summary: "The ridge is sharp and the axe answers at once.",
                viewDistance: 2_400,
                steerSlip: 0,
                gustAmplitude: 0,
                lightningPeriod: 0,
                lightningDuration: 0,
                tagBoosts: [:],
                telegraphsRocks: false,
                warningLead: 0
            )
        case .rain:
            return WeatherDefinition(
                kind: .rain,
                name: "Rain",
                summary: "The shale is slick. Steps keep going after you lift your thumb. Stone charms grip harder.",
                viewDistance: 640,
                steerSlip: 0.78,
                gustAmplitude: 0,
                lightningPeriod: 0,
                lightningDuration: 0,
                tagBoosts: [.stone: 0.25],
                telegraphsRocks: true,
                warningLead: 0.85
            )
        case .blizzard:
            return WeatherDefinition(
                kind: .blizzard,
                name: "Blizzard",
                summary: "Whiteout shortens the view and gusts shove you sideways. Frost charms bite deeper.",
                viewDistance: 260,
                steerSlip: 0.12,
                gustAmplitude: 78,
                lightningPeriod: 0,
                lightningDuration: 0,
                tagBoosts: [.frost: 0.25],
                telegraphsRocks: true,
                warningLead: 0.95
            )
        case .nightStorm:
            return WeatherDefinition(
                kind: .nightStorm,
                name: "Night Storm",
                summary: "Dark hides the next rock. Lightning opens the ridge for a breath. Gale charms run hotter.",
                viewDistance: 220,
                steerSlip: 0.18,
                gustAmplitude: 34,
                lightningPeriod: 4.2,
                lightningDuration: 0.22,
                tagBoosts: [.gale: 0.25],
                telegraphsRocks: true,
                warningLead: 0.9
            )
        }
    }

    public static var all: [WeatherDefinition] {
        WeatherKind.allCases.map(definition(for:))
    }

    /// Stable for a stage and a run seed. Does not draw from the simulation's spawn stream.
    public static func kind(stage: StageID, seed: UInt64) -> WeatherKind {
        var rng = SplitMix64(seed: seed ^ (UInt64(stage.rawValue) &* 0x6C62_272E_EBFD_5C15))
        let index = rng.nextInt(upperBound: WeatherKind.allCases.count)
        return WeatherKind.allCases[index]
    }

    public static func resolve(stage: StageID, config: SimConfig) -> WeatherDefinition {
        let kind = config.forcedWeather ?? kind(stage: stage, seed: config.seed)
        return definition(for: kind)
    }

    public static func scaled(_ effect: CharmEffect, multiplier: Double) -> CharmEffect {
        guard multiplier != 1 else { return effect }
        switch effect {
        case .climbSpeed(let fraction):
            return .climbSpeed(fraction: fraction * multiplier)
        case .attackDamage(let fraction):
            return .attackDamage(fraction: fraction * multiplier)
        case .attackCooldown(let fraction):
            return .attackCooldown(fraction: fraction * multiplier)
        case .attackRange(let fraction):
            return .attackRange(fraction: fraction * multiplier)
        case .extraTargets(let count):
            return .extraTargets(count)
        case .maxHealth(let amount):
            return .maxHealth(amount * multiplier)
        case .avalancheDrag(let speed):
            return .avalancheDrag(speed: speed * multiplier)
        case .contactArmor(let fraction):
            return .contactArmor(fraction: fraction * multiplier)
        case .emberYield(let fraction):
            return .emberYield(fraction: fraction * multiplier)
        case .healOnCairn(let amount):
            return .healOnCairn(amount * multiplier)
        case .burnDamage(let amount):
            return .burnDamage(amount * multiplier)
        }
    }
}
