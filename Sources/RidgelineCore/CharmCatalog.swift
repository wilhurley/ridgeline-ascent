import Foundation

public struct CharmDefinition: Equatable, Identifiable, Codable {
    public let id: String
    public let name: String
    public let tag: ElementTag
    public let summary: String
    public let effects: [CharmEffect]

    public init(id: String, name: String, tag: ElementTag, summary: String, effects: [CharmEffect]) {
        self.id = id
        self.name = name
        self.tag = tag
        self.summary = summary
        self.effects = effects
    }
}

public struct FusionDefinition: Equatable, Identifiable, Codable {
    public let id: String
    public let name: String
    public let summary: String
    public let requires: [String]
    public let effects: [CharmEffect]

    public init(id: String, name: String, summary: String, requires: [String], effects: [CharmEffect]) {
        self.id = id
        self.name = name
        self.summary = summary
        self.requires = requires
        self.effects = effects
    }

    public func isUnlocked(owned: Set<String>) -> Bool {
        !requires.isEmpty && requires.allSatisfy { owned.contains($0) }
    }
}

public struct SetBonusDefinition: Equatable, Identifiable, Codable {
    public let id: String
    public let tag: ElementTag
    public let threshold: Int
    public let name: String
    public let summary: String
    public let effects: [CharmEffect]

    public init(
        id: String,
        tag: ElementTag,
        threshold: Int,
        name: String,
        summary: String,
        effects: [CharmEffect]
    ) {
        self.id = id
        self.tag = tag
        self.threshold = threshold
        self.name = name
        self.summary = summary
        self.effects = effects
    }
}

public enum CatalogError: Error, Equatable {
    case missingResource
    case unreadable
    case invalid(String)
}

public struct CharmCatalog: Equatable {
    public let charms: [CharmDefinition]
    public let fusions: [FusionDefinition]
    public let setBonuses: [SetBonusDefinition]

    public init(charms: [CharmDefinition], fusions: [FusionDefinition], setBonuses: [SetBonusDefinition]) {
        self.charms = charms
        self.fusions = fusions
        self.setBonuses = setBonuses
    }

    public static let starter: CharmCatalog = {
        do {
            return try loadFromModule()
        } catch {
            fatalError("Ridgeline charm catalog failed to load: \(error)")
        }
    }()

    public static func loadFromModule() throws -> CharmCatalog {
        guard let url = Bundle.module.url(forResource: "catalog", withExtension: "json") else {
            throw CatalogError.missingResource
        }
        return try load(from: url)
    }

    public static func load(from url: URL) throws -> CharmCatalog {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw CatalogError.unreadable
        }
        let file: CatalogFile
        do {
            file = try JSONDecoder().decode(CatalogFile.self, from: data)
        } catch {
            throw CatalogError.invalid(String(describing: error))
        }
        let catalog = CharmCatalog(charms: file.charms, fusions: file.fusions, setBonuses: file.setBonuses)
        try catalog.validate()
        return catalog
    }

    public func charm(id: String) -> CharmDefinition? {
        charms.first { $0.id == id }
    }

    /// Shuffles the unowned pool with `rng` and returns up to `count` offers.
    public func offers(count: Int, excluding: Set<String>, rng: inout SplitMix64) -> [CharmDefinition] {
        guard count > 0 else { return [] }
        var pool = charms.filter { !excluding.contains($0.id) }
        if pool.count > 1 {
            for index in stride(from: pool.count - 1, through: 1, by: -1) {
                let swap = rng.nextInt(upperBound: index + 1)
                if swap != index {
                    pool.swapAt(index, swap)
                }
            }
        }
        return Array(pool.prefix(count))
    }

    public func validate() throws {
        let ids = charms.map(\.id)
        guard Set(ids).count == ids.count else {
            throw CatalogError.invalid("Duplicate charm id")
        }
        for charm in charms {
            if charm.id.isEmpty || charm.name.isEmpty || charm.effects.isEmpty {
                throw CatalogError.invalid("Charm \(charm.id) is incomplete")
            }
        }
        let known = Set(ids)
        var fusionIDs = Set<String>()
        for fusion in fusions {
            if fusion.id.isEmpty || fusion.requires.count < 2 || fusion.effects.isEmpty {
                throw CatalogError.invalid("Fusion \(fusion.id) is incomplete")
            }
            if !fusionIDs.insert(fusion.id).inserted {
                throw CatalogError.invalid("Duplicate fusion id \(fusion.id)")
            }
            for required in fusion.requires where !known.contains(required) {
                throw CatalogError.invalid("Fusion \(fusion.id) requires unknown charm \(required)")
            }
        }
        var seenThresholds = Set<String>()
        for bonus in setBonuses {
            if bonus.threshold != 2 && bonus.threshold != 4 {
                throw CatalogError.invalid("Set bonus \(bonus.id) must be a 2-piece or 4-piece")
            }
            let key = "\(bonus.tag.rawValue)#\(bonus.threshold)"
            if !seenThresholds.insert(key).inserted {
                throw CatalogError.invalid("Duplicate set bonus \(key)")
            }
            if bonus.effects.isEmpty {
                throw CatalogError.invalid("Set bonus \(bonus.id) has no effects")
            }
        }
        for tag in ElementTag.allCases {
            for threshold in [2, 4] {
                let key = "\(tag.rawValue)#\(threshold)"
                if !seenThresholds.contains(key) {
                    throw CatalogError.invalid("Missing set bonus \(key)")
                }
            }
        }
    }
}

private struct CatalogFile: Codable {
    let charms: [CharmDefinition]
    let fusions: [FusionDefinition]
    let setBonuses: [SetBonusDefinition]
}
