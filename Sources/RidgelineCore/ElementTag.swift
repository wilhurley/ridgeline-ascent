/// Element carried by a trail charm. Two and four copies of a tag open set bonuses.
public enum ElementTag: String, Codable, Equatable, CaseIterable, Identifiable {
    case frost
    case ember
    case gale
    case stone
    case spirit

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .frost: return "Frost"
        case .ember: return "Ember"
        case .gale: return "Gale"
        case .stone: return "Stone"
        case .spirit: return "Spirit"
        }
    }
}
