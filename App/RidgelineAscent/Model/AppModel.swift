import Foundation
import SwiftUI
import RidgelineCore

struct HudSnapshot: Equatable {
    var stageName = "Scree Approach"
    var altitude = 0
    var healthFraction = 1.0
    var leadFraction = 1.0
    var score = 0
    var charmCount = 0
    var daily = false
    var gear = "Ice Axe"

    init() {}

    init(simulation: RidgeSimulation, daily: Bool) {
        stageName = simulation.stage.displayName
        altitude = Int(simulation.climber.y.rounded(.down))
        let maxHealth = max(simulation.climber.maxHealth, 1)
        healthFraction = min(1, max(0, simulation.climber.health / maxHealth))
        let span = max(simulation.config.startingLead, 1)
        leadFraction = min(1, max(0, simulation.lead / span))
        score = simulation.score.points
        charmCount = simulation.ownedCharms.count
        self.daily = daily
        gear = simulation.loadout.gearStyle.displayName
    }
}

final class AppModel: ObservableObject, GameDirecting {
    enum Route: Equatable {
        case title
        case playing
        case results
    }

    @Published var route: Route = .title
    @Published var scene: RidgeScene?
    @Published var runID = UUID()
    @Published var hud = HudSnapshot()
    @Published var showCairn = false
    @Published var cairnOffers: [CharmDefinition] = []
    @Published var showDefeat = false
    @Published var rewardPrompt: RewardedPlacement?
    @Published var summary: RunSummary?
    @Published var embersBalance = 0
    @Published var embersGranted = 0
    @Published var ownsSummitPack = false
    @Published var showSummitPack = false
    @Published var toast: String?
    @Published var dailyActive = false
    @Published var newBest = false
    @Published var bestAltitude = 0
    @Published var bestDaily = 0
    @Published var leaderboardNote = "Game Center hook is ready. Sign-in is not linked yet."
    @Published var doubledThisRun = false

    let wallet: EmbersWallet
    let ads: PlaceholderRewardedAds
    let store: SummitPackHook
    let leaderboards: GameCenterHook
    let bests: LocalBestStore
    let haptics: HapticHook

    private var session: RunSession?
    private var defeatLatch = false
    private var pendingReward: ((RewardedAdResult) -> Void)?
    private var toastToken = 0

    init() {
        let defaults = UserDefaults.standard
        wallet = EmbersWallet(balance: defaults.integer(forKey: StorageKey.embers)) { value in
            defaults.set(value, forKey: StorageKey.embers)
        }
        ads = PlaceholderRewardedAds()
        store = SummitPackHook(defaults: defaults)
        leaderboards = GameCenterHook()
        bests = LocalBestStore(defaults: defaults)
        haptics = HapticHook()
        embersBalance = wallet.balance
        ownsSummitPack = store.ownsSummitPack
        bestAltitude = bests.bestAltitude
        bestDaily = bests.bestDaily
        ads.present = { [weak self] placement, completion in
            self?.pendingReward = completion
            self?.rewardPrompt = placement
        }
    }

    var showsBanner: Bool { !ownsSummitPack }

    var canOfferDouble: Bool {
        session?.canOfferDoubleRewards == true
    }

    func start(daily: Bool) {
        dailyActive = daily
        var config = SimConfig.standard
        if daily {
            config.seed = DailyRun.seed(for: Date())
        } else {
            config.seed = UInt64.random(in: 1...999_999_999)
        }
        let simulation = RidgeSimulation(config: config)
        session = RunSession(
            simulation: simulation,
            daily: daily,
            wallet: wallet,
            ownsSummitPack: store.ownsSummitPack,
            ads: ads,
            leaderboards: leaderboards
        )
        let nextScene = RidgeScene(simulation: simulation)
        nextScene.director = self
        nextScene.scaleMode = .resizeFill
        defeatLatch = false
        showCairn = false
        cairnOffers = []
        showDefeat = false
        rewardPrompt = nil
        pendingReward = nil
        summary = nil
        newBest = false
        doubledThisRun = false
        embersGranted = 0
        toast = nil
        scene = nextScene
        runID = UUID()
        route = .playing
        sync(from: simulation)
    }

    func chooseCharm(_ id: String) {
        guard let simulation = session?.simulation else { return }
        guard simulation.chooseCharm(id: id) else { return }
        showCairn = false
        cairnOffers = []
        haptics.play(.charm)
        SoundBoard.shared.play(.charm)
        sync(from: simulation)
    }

    func requestRevive() {
        session?.requestRevive { [weak self] outcome in
            guard let self else { return }
            if case .revived = outcome {
                self.showDefeat = false
                self.defeatLatch = false
                self.haptics.play(.revive)
            }
        }
    }

    func abandonRun() {
        showDefeat = false
        let completion = pendingReward
        pendingReward = nil
        rewardPrompt = nil
        completion?(.dismissed)
        finishRun()
    }

    func requestDoubleRewards() {
        session?.requestDoubleRewards { [weak self] outcome in
            guard let self else { return }
            if case .doubled(let extra) = outcome {
                self.embersGranted = self.session?.embersGranted ?? self.embersGranted
                self.embersBalance = self.wallet.balance
                self.doubledThisRun = true
                self.announce("+\(extra) Embers")
            }
        }
    }

    func resolveReward(earned: Bool) {
        let completion = pendingReward
        pendingReward = nil
        rewardPrompt = nil
        completion?(earned ? .earned : .dismissed)
    }

    func purchaseSummitPack() {
        let outcome = store.purchase()
        ownsSummitPack = store.ownsSummitPack
        showSummitPack = false
        if outcome == .owned {
            announce("Summit Pack is on this device. Banners stay off the trail.")
        }
    }

    func restoreSummitPack() {
        let outcome = store.restore()
        ownsSummitPack = store.ownsSummitPack
        showSummitPack = false
        if outcome == .owned {
            announce("Summit Pack restored on this device.")
        } else {
            announce("Nothing to restore yet.")
        }
    }

    func returnToTitle() {
        route = .title
        scene = nil
        session = nil
        showCairn = false
        showDefeat = false
        rewardPrompt = nil
        embersBalance = wallet.balance
        bestAltitude = bests.bestAltitude
        bestDaily = bests.bestDaily
        ownsSummitPack = store.ownsSummitPack
    }

    func sync(from simulation: RidgeSimulation) {
        let nextHud = HudSnapshot(simulation: simulation, daily: dailyActive)
        if nextHud != hud {
            hud = nextHud
        }
        switch simulation.phase {
        case .cairn(let offers):
            if !showCairn {
                cairnOffers = offers
                showCairn = true
                haptics.play(.cairn)
            }
        case .climbing, .boss:
            if showCairn {
                showCairn = false
            }
            defeatLatch = false
            if showDefeat {
                showDefeat = false
            }
        case .defeated:
            guard route == .playing, summary == nil, !defeatLatch else { return }
            defeatLatch = true
            if session?.canOfferRevive == true {
                showDefeat = true
            } else {
                finishRun()
            }
        case .summit:
            guard route == .playing, summary == nil else { return }
            finishRun()
        }
    }

    func announce(_ message: String) {
        toast = message
        toastToken += 1
        let token = toastToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
            guard let self, self.toastToken == token else { return }
            self.toast = nil
        }
    }

    private func finishRun() {
        guard route == .playing, let session else { return }
        let settled = session.settleIfNeeded()
        summary = settled
        embersGranted = session.embersGranted
        embersBalance = wallet.balance
        if let settled {
            let altitude = Int(settled.score.altitude.rounded(.down))
            newBest = bests.record(altitude: altitude, daily: settled.daily)
            bestAltitude = bests.bestAltitude
            bestDaily = bests.bestDaily
            leaderboardNote = leaderboards.lastNote
        }
        showCairn = false
        showDefeat = false
        route = .results
    }
}
