import Foundation

extension CharmEffect {
    /// Player-facing line. Numbers come from the effect itself.
    public var playerLine: String {
        switch self {
        case .climbSpeed(let fraction):
            return "Climb speed \(Self.percent(fraction))"
        case .attackDamage(let fraction):
            return "Attack damage \(Self.percent(fraction))"
        case .attackCooldown(let fraction):
            return "Attack cooldown \(Self.percent(fraction))"
        case .attackRange(let fraction):
            return "Attack range \(Self.percent(fraction))"
        case .extraTargets(let count):
            return count == 1 ? "Hits 1 extra target" : "Hits \(count) extra targets"
        case .maxHealth(let amount):
            return "Max health +\(Self.whole(amount))"
        case .avalancheDrag(let speed):
            return "Slows the avalanche by \(Self.whole(speed))"
        case .contactArmor(let fraction):
            return "Contact damage taken \(Self.percent(-abs(fraction)))"
        case .emberYield(let fraction):
            return "Ember yield \(Self.percent(fraction))"
        case .healOnCairn(let amount):
            return "Heal \(Self.whole(amount)) at each cairn"
        case .burnDamage(let amount):
            return "Burn \(Self.whole(amount)) on each hit"
        }
    }

    private static func percent(_ fraction: Double) -> String {
        let value = Int((fraction * 100).rounded())
        if value < 0 {
            return "−\(abs(value))%"
        }
        return "+\(value)%"
    }

    private static func whole(_ value: Double) -> String {
        String(Int(value.rounded()))
    }
}

public struct CharmDossier: Equatable, Identifiable {
    public let id: String
    public let name: String
    public let tag: ElementTag
    public let summary: String
    public let effectLines: [String]
    public let combinations: [String]
    public let discovered: Bool
}

public struct FusionDossier: Equatable, Identifiable {
    public let id: String
    public let discovered: Bool
    public let name: String
    public let summary: String
    public let requirement: String
}

public struct TagProgress: Equatable, Identifiable {
    public let tag: ElementTag
    public let count: Int
    public let nextThreshold: Int?
    public let activeBonusName: String?
    public let twoPieceName: String
    public let twoPieceEffect: String
    public let fourPieceName: String
    public let fourPieceEffect: String

    public var id: String { tag.rawValue }

    public static func snapshot(owned: [CharmDefinition], catalog: CharmCatalog) -> [TagProgress] {
        let counts = Dictionary(grouping: owned, by: \.tag).mapValues(\.count)
        return ElementTag.allCases.map { tag in
            let count = counts[tag] ?? 0
            let bonuses = catalog.setBonuses.filter { $0.tag == tag }.sorted { $0.threshold < $1.threshold }
            let two = bonuses.first { $0.threshold == 2 }
            let four = bonuses.first { $0.threshold == 4 }
            let active = bonuses.filter { count >= $0.threshold }.last
            let next: Int?
            if count < 2 {
                next = 2
            } else if count < 4 {
                next = 4
            } else {
                next = nil
            }
            return TagProgress(
                tag: tag,
                count: count,
                nextThreshold: next,
                activeBonusName: active?.name,
                twoPieceName: two?.name ?? "Pair",
                twoPieceEffect: two?.effects.map(\.playerLine).joined(separator: ", ") ?? "",
                fourPieceName: four?.name ?? "Set",
                fourPieceEffect: four?.effects.map(\.playerLine).joined(separator: ", ") ?? ""
            )
        }
    }
}

public struct GearDossier: Equatable, Identifiable {
    public let style: GearStyle
    public let summary: String
    public let charmNote: String
    public let damage: Double
    public let burn: Double
    public let cooldown: Double
    public let range: Double
    public let targets: Int

    public var id: String { style.rawValue }
}

public struct HazardDossier: Equatable, Identifiable {
    public let id: String
    public let name: String
    public let summary: String
}

public struct DiscoveryLog: Equatable, Codable {
    public private(set) var charmIDs: Set<String>
    public private(set) var fusionIDs: Set<String>

    public init(charmIDs: Set<String> = [], fusionIDs: Set<String> = []) {
        self.charmIDs = charmIDs
        self.fusionIDs = fusionIDs
    }

    public func knowsCharm(_ id: String) -> Bool { charmIDs.contains(id) }
    public func knowsFusion(_ id: String) -> Bool { fusionIDs.contains(id) }

    @discardableResult
    public mutating func recordCharm(_ id: String) -> Bool {
        charmIDs.insert(id).inserted
    }

    @discardableResult
    public mutating func recordFusion(_ id: String) -> Bool {
        fusionIDs.insert(id).inserted
    }
}

public enum FieldGuide {
    public static func charmDossier(
        _ charm: CharmDefinition,
        catalog: CharmCatalog,
        discovered: DiscoveryLog,
        revealFusions: Bool
    ) -> CharmDossier {
        CharmDossier(
            id: charm.id,
            name: charm.name,
            tag: charm.tag,
            summary: charm.summary,
            effectLines: charm.effects.map(\.playerLine),
            combinations: combinationLines(for: charm, catalog: catalog, discovered: discovered, revealFusions: revealFusions),
            discovered: discovered.knowsCharm(charm.id)
        )
    }

    public static func charms(catalog: CharmCatalog, discovered: DiscoveryLog, revealFusions: Bool) -> [CharmDossier] {
        catalog.charms.map { charmDossier($0, catalog: catalog, discovered: discovered, revealFusions: revealFusions) }
    }

    public static func fusions(catalog: CharmCatalog, discovered: DiscoveryLog) -> [FusionDossier] {
        catalog.fusions.map { fusion in
            let known = discovered.knowsFusion(fusion.id)
            if known {
                let names = fusion.requires.compactMap { catalog.charm(id: $0)?.name }
                return FusionDossier(
                    id: fusion.id,
                    discovered: true,
                    name: fusion.name,
                    summary: fusion.summary,
                    requirement: names.joined(separator: " + ")
                )
            }
            return FusionDossier(
                id: fusion.id,
                discovered: false,
                name: "???",
                summary: "Not found yet.",
                requirement: "???"
            )
        }
    }

    public static func combinationLines(
        for charm: CharmDefinition,
        catalog: CharmCatalog,
        discovered: DiscoveryLog,
        revealFusions: Bool
    ) -> [String] {
        catalog.fusions.compactMap { fusion in
            guard fusion.requires.contains(charm.id) else { return nil }
            let partners = fusion.requires
                .filter { $0 != charm.id }
                .map { catalog.charm(id: $0)?.name ?? "a charm" }
            let partnerText = partners.joined(separator: " and ")
            let show = revealFusions || discovered.knowsFusion(fusion.id)
            if show {
                return "With \(partnerText): \(fusion.name)"
            }
            return "With \(partnerText): ???"
        }
    }

    /// Weapon numbers from `Loadout.resolve`, with burn and extra targets stripped so each tool is itself.
    public static func gear(config: SimConfig) -> [GearDossier] {
        var neutral = config
        neutral.bonusBurn = 0
        neutral.bonusArmor = 0
        let axe = Loadout.resolve(config: neutral, effects: [])
        let flare = Loadout.resolve(config: neutral, effects: [.burnDamage(1)])
        let hook = Loadout.resolve(config: neutral, effects: [.extraTargets(1)])
        return [
            GearDossier(
                style: .iceAxe,
                summary: "A single cut at the nearest hazard. This is the guide's axe and the hauler's hammer-axe.",
                charmNote: "Damage, cooldown, and range charms change these numbers. Burn replaces the swing with the flare. An extra target replaces it with the rope hook.",
                damage: axe.damage,
                burn: axe.burnDamage,
                cooldown: axe.cooldown,
                range: axe.range,
                targets: axe.targets
            ),
            GearDossier(
                style: .flare,
                summary: "The flare sticks. Burn damage is added on top of the hit.",
                charmNote: "Any burn, including the scout's starting flare, selects this swing.",
                damage: flare.damage,
                burn: flare.burnDamage,
                cooldown: flare.cooldown,
                range: flare.range,
                targets: flare.targets
            ),
            GearDossier(
                style: .ropeHook,
                summary: "The hook reaches a second hazard when a charm adds a target.",
                charmNote: "Extra targets select this swing, unless burn is also present. Burn wins and the flare is used.",
                damage: hook.damage,
                burn: hook.burnDamage,
                cooldown: hook.cooldown,
                range: hook.range,
                targets: hook.targets
            )
        ]
    }

    public static func hazards() -> [HazardDossier] {
        let pebble = Rockfall.spec(.pebble, stage: .screeApproach)
        let boulder = Rockfall.spec(.boulder, stage: .screeApproach)
        let slab = Rockfall.spec(.slab, stage: .screeApproach)
        return [
            HazardDossier(
                id: "pebble",
                name: "Pebble",
                summary: "Small and fast. About \(Int((pebble?.health ?? 0).rounded())) health on the first stage, one clean hit. It does not split."
            ),
            HazardDossier(
                id: "boulder",
                name: "Boulder",
                summary: "A medium rock, about \(Int((boulder?.health ?? 0).rounded())) health on the approach. It takes more than one swing."
            ),
            HazardDossier(
                id: "slab",
                name: "Slab",
                summary: "Large and slow, about \(Int((slab?.health ?? 0).rounded())) health. When it breaks it splits into a boulder and a pebble."
            ),
            HazardDossier(
                id: "ice_wraith",
                name: "Ice Wraith",
                summary: "Drifts toward your lane. Appears from the ice shelf onward."
            ),
            HazardDossier(
                id: "storm_crow",
                name: "Storm Crow",
                summary: "Crosses the ridge. Shows up on the eave and at the cornice."
            ),
            HazardDossier(
                id: "cornice",
                name: "Cornice Tyrant",
                summary: "The summit boss. It stays ahead of you and sweeps the ridge. Break it to finish the ascent."
            ),
            HazardDossier(
                id: "avalanche",
                name: "Avalanche",
                summary: "It wants a shrinking gap under your boots. Hits slow you and do not slow it. If the gap closes, the ascent ends."
            )
        ]
    }
}

public enum TutorialBeat: Int, Equatable, CaseIterable {
    case steer
    case strike
    case avalanche
    case cairn
    case setBonus
    case done
}

public enum TutorialScript {
    public static let cairnOfferIDs = ["rime_edge", "cinder_flare", "granite_hide"]

    public static func configuration(seed: UInt64) -> SimConfig {
        var config = SimConfig.standard
        config.seed = seed
        config.spawnsEnabled = false
        config.cairnInterval = 10_000
        config.startingLead = 240
        config.minLead = 170
        config.forcedWeather = .clear
        config.stageDurations = [80, 80, 80]
        return config
    }

    public static func prompt(_ beat: TutorialBeat, tag: ElementTag?) -> String {
        switch beat {
        case .steer:
            return "Drag anywhere to step aside."
        case .strike:
            return "The axe swings by itself."
        case .avalanche:
            return "Keep above the white."
        case .cairn:
            return "Pick one charm."
        case .setBonus:
            if let tag {
                return "\(tag.displayName) 1 of 2. Another opens a bonus."
            }
            return "Two of a tag opens a bonus."
        case .done:
            return "The ridge is yours."
        }
    }

    public static func nextBeat(
        _ beat: TutorialBeat,
        moved: Bool,
        hazardsDefeated: Int,
        elapsedInBeat: Double,
        charmsOwned: Int
    ) -> TutorialBeat {
        switch beat {
        case .steer:
            return moved ? .strike : .steer
        case .strike:
            return hazardsDefeated > 0 ? .avalanche : .strike
        case .avalanche:
            return elapsedInBeat >= 4 ? .cairn : .avalanche
        case .cairn:
            return charmsOwned > 0 ? .setBonus : .cairn
        case .setBonus:
            return elapsedInBeat >= 3.2 ? .done : .setBonus
        case .done:
            return .done
        }
    }
}
