/// Game Center leaderboard identifiers. The app layer submits; this module
/// only names the boards so tests can lock the ids.
public enum LeaderboardID: String, Equatable, CaseIterable, Identifiable {
    case bestAltitude = "com.ridgelineapps.ridgelineascent.leaderboard.altitude"
    case dailyAscent = "com.ridgelineapps.ridgelineascent.leaderboard.daily"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .bestAltitude: return "High Ridge"
        case .dailyAscent: return "Daily Ascent"
        }
    }
}

public protocol LeaderboardSubmitting: AnyObject {
    func submit(score: Int, leaderboard: LeaderboardID)
}
