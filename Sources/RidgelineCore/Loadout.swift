import Foundation

/// How the climber's kit fires. The simulation picks this from the active effects
/// so the scene can draw an axe, a flare, or a rope-hook without owning the rules.
public enum GearStyle: String, Codable, Equatable, CaseIterable {
    case iceAxe
    case flare
    case ropeHook

    public var displayName: String {
        switch self {
        case .iceAxe: return "Ice Axe"
        case .flare: return "Flare"
        case .ropeHook: return "Rope Hook"
        }
    }
}

/// Resolved combat and survival numbers for the current charm loadout.
public struct Loadout: Equatable {
    public var climbSpeed: Double
    public var damage: Double
    public var cooldown: Double
    public var range: Double
    public var targets: Int
    public var maxHealth: Double
    public var avalancheDrag: Double
    public var armor: Double
    public var emberYield: Double
    public var healOnCairn: Double
    public var burnDamage: Double
    public var gearStyle: GearStyle

    public static func resolve(config: SimConfig, effects: [CharmEffect]) -> Loadout {
        var climbFraction = 0.0
        var damageFraction = 0.0
        var cooldownFraction = 0.0
        var rangeFraction = 0.0
        var extraTargets = 0
        var bonusHealth = 0.0
        var drag = 0.0
        var armor = 0.0
        var emberYield = 0.0
        var healOnCairn = 0.0
        var burn = config.bonusBurn
        armor += config.bonusArmor

        for effect in effects {
            switch effect {
            case .climbSpeed(let fraction):
                climbFraction += fraction
            case .attackDamage(let fraction):
                damageFraction += fraction
            case .attackCooldown(let fraction):
                cooldownFraction += fraction
            case .attackRange(let fraction):
                rangeFraction += fraction
            case .extraTargets(let count):
                extraTargets += count
            case .maxHealth(let amount):
                bonusHealth += amount
            case .avalancheDrag(let speed):
                drag += speed
            case .contactArmor(let fraction):
                armor += fraction
            case .emberYield(let fraction):
                emberYield += fraction
            case .healOnCairn(let amount):
                healOnCairn += amount
            case .burnDamage(let amount):
                burn += amount
            }
        }

        let style: GearStyle
        if burn > 0 {
            style = .flare
        } else if extraTargets > 0 {
            style = .ropeHook
        } else {
            style = .iceAxe
        }

        return Loadout(
            climbSpeed: config.baseClimbSpeed * (1 + climbFraction),
            damage: max(0, config.baseAttackDamage * (1 + damageFraction)),
            cooldown: max(0.12, config.baseAttackCooldown * (1 + cooldownFraction)),
            range: max(24, config.baseAttackRange * (1 + rangeFraction)),
            targets: max(1, 1 + extraTargets),
            maxHealth: max(1, config.baseMaxHealth + bonusHealth),
            avalancheDrag: max(0, drag),
            armor: min(0.65, max(0, armor)),
            emberYield: max(0, emberYield),
            healOnCairn: max(0, healOnCairn),
            burnDamage: max(0, burn),
            gearStyle: style
        )
    }
}
