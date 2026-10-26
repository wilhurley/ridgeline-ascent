import Foundation

/// One numeric modifier contributed by a charm, a set bonus, or a fusion.
/// Fractions are additive with each other: two `climbSpeed(fraction: 0.10)`
/// effects become a 1.20 climb multiplier.
public enum CharmEffect: Equatable, Codable {
    case climbSpeed(fraction: Double)
    case attackDamage(fraction: Double)
    case attackCooldown(fraction: Double)
    case attackRange(fraction: Double)
    case extraTargets(Int)
    case maxHealth(Double)
    case avalancheDrag(speed: Double)
    case contactArmor(fraction: Double)
    case emberYield(fraction: Double)
    case healOnCairn(Double)
    case burnDamage(Double)

    private enum CodingKeys: String, CodingKey {
        case type
        case fraction
        case amount
        case count
        case speed
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "climbSpeed":
            self = .climbSpeed(fraction: try container.decode(Double.self, forKey: .fraction))
        case "attackDamage":
            self = .attackDamage(fraction: try container.decode(Double.self, forKey: .fraction))
        case "attackCooldown":
            self = .attackCooldown(fraction: try container.decode(Double.self, forKey: .fraction))
        case "attackRange":
            self = .attackRange(fraction: try container.decode(Double.self, forKey: .fraction))
        case "extraTargets":
            self = .extraTargets(try container.decode(Int.self, forKey: .count))
        case "maxHealth":
            self = .maxHealth(try container.decode(Double.self, forKey: .amount))
        case "avalancheDrag":
            self = .avalancheDrag(speed: try container.decode(Double.self, forKey: .speed))
        case "contactArmor":
            self = .contactArmor(fraction: try container.decode(Double.self, forKey: .fraction))
        case "emberYield":
            self = .emberYield(fraction: try container.decode(Double.self, forKey: .fraction))
        case "healOnCairn":
            self = .healOnCairn(try container.decode(Double.self, forKey: .amount))
        case "burnDamage":
            self = .burnDamage(try container.decode(Double.self, forKey: .amount))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown charm effect type \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .climbSpeed(let fraction):
            try container.encode("climbSpeed", forKey: .type)
            try container.encode(fraction, forKey: .fraction)
        case .attackDamage(let fraction):
            try container.encode("attackDamage", forKey: .type)
            try container.encode(fraction, forKey: .fraction)
        case .attackCooldown(let fraction):
            try container.encode("attackCooldown", forKey: .type)
            try container.encode(fraction, forKey: .fraction)
        case .attackRange(let fraction):
            try container.encode("attackRange", forKey: .type)
            try container.encode(fraction, forKey: .fraction)
        case .extraTargets(let count):
            try container.encode("extraTargets", forKey: .type)
            try container.encode(count, forKey: .count)
        case .maxHealth(let amount):
            try container.encode("maxHealth", forKey: .type)
            try container.encode(amount, forKey: .amount)
        case .avalancheDrag(let speed):
            try container.encode("avalancheDrag", forKey: .type)
            try container.encode(speed, forKey: .speed)
        case .contactArmor(let fraction):
            try container.encode("contactArmor", forKey: .type)
            try container.encode(fraction, forKey: .fraction)
        case .emberYield(let fraction):
            try container.encode("emberYield", forKey: .type)
            try container.encode(fraction, forKey: .fraction)
        case .healOnCairn(let amount):
            try container.encode("healOnCairn", forKey: .type)
            try container.encode(amount, forKey: .amount)
        case .burnDamage(let amount):
            try container.encode("burnDamage", forKey: .type)
            try container.encode(amount, forKey: .amount)
        }
    }
}
