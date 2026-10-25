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
    @Published var tagProgress: [TagProgress] = TagProgress.snapshot(owned: [], catalog: .starter)
    @Published var runCharms: [CharmDefinition] = []
    @Published var runBonuses: [SetBonusDefinition] = []
    @Published var runFusions: [FusionDefinition] = []
    @Published var isPaused = false
    @Published var showHowToPlay = false
    @Published var showEquipment = false
    @Published var showClimbers = false
    @Published var weatherCallout: WeatherDefinition?
    @Published var tutorialBeat: TutorialBeat?
    @Published var tutorialTag: ElementTag?
    @Published var locker = ClimberLocker.fresh
    @Published var discovery = DiscoveryLog()

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
    private var weatherToken = 0
    private var tutorialSeen = false
    private var didOfferTutorial = false
    private var tutorialOriginX = 0.0
    private var tutorialBeatStart = 0.0
    private var tutorialArmed: TutorialBeat?
    private let defaults = UserDefaults.standard

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
        if let data = defaults.data(forKey: StorageKey.locker),
           let saved = try? JSONDecoder().decode(ClimberLocker.self, from: data) {
            locker = saved
        }
        if let data = defaults.data(forKey: StorageKey.discovery),
           let saved = try? JSONDecoder().decode(DiscoveryLog.self, from: data) {
            discovery = saved
        }
        tutorialSeen = defaults.bool(forKey: StorageKey.tutorialSeen)
        ads.present = { [weak self] placement, completion in
            self?.pendingReward = completion
            self?.rewardPrompt = placement
        }
    }

    var showsBanner: Bool { !ownsSummitPack }

    var canOfferDouble: Bool {
        session?.canOfferDoubleRewards == true
    }

    var ticksSimulation: Bool { !isPaused }

    var selectedProfile: ClimberProfile {
        ClimberRoster.profile(id: locker.selectedID)
    }

    var tutorialPrompt: String? {
        guard let tutorialBeat, tutorialBeat != .done else { return nil }
        return TutorialScript.prompt(tutorialBeat, tag: tutorialTag)
    }

    func onLaunch() {
        guard !didOfferTutorial else { return }
        didOfferTutorial = true
        if !tutorialSeen {
            startTutorial()
        }
    }

    func start(daily: Bool) {
        begin(daily: daily, tutorial: false)
    }

    func startTutorial() {
        begin(daily: false, tutorial: true)
    }

    func skipTutorial() {
        tutorialBeat = nil
        markTutorialSeen()
        returnToTitle()
        announce("You can practice that ascent again from the trailhead.")
    }

    private func begin(daily: Bool, tutorial: Bool) {
        dailyActive = daily
        var config = tutorial ? TutorialScript.configuration(seed: UInt64.random(in: 1...999_999_999)) : SimConfig.standard
        config = ClimberRoster.applying(selectedProfile, to: config)
        if daily && !tutorial {
            config.seed = DailyRun.seed(for: Date())
        } else if !tutorial {
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
        isPaused = false
        scene = nextScene
        runID = UUID()
        route = .playing
        tutorialBeat = tutorial ? .steer : nil
        tutorialTag = nil
        tutorialOriginX = simulation.climber.x
        tutorialBeatStart = 0
        tutorialArmed = nil
        showWeather(simulation.weather)
        sync(from: simulation)
    }

    func chooseCharm(_ id: String) {
        guard let simulation = session?.simulation else { return }
        guard simulation.chooseCharm(id: id) else { return }
        if let tag = simulation.ownedCharms.last?.tag {
            tutorialTag = tag
        }
        recordDiscoveries(from: simulation)
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
        isPaused = false
        tutorialBeat = nil
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
        tagProgress = TagProgress.snapshot(owned: simulation.ownedCharms, catalog: simulation.catalog)
        runCharms = simulation.ownedCharms
        runBonuses = simulation.activeSetBonuses
        runFusions = simulation.activeFusions
        recordDiscoveries(from: simulation)
        advanceTutorial(simulation)
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
            if tutorialBeat != nil {
                completeTutorial()
                return
            }
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

    func noteWeather(_ kind: WeatherKind) {
        showWeather(WeatherTable.definition(for: kind))
    }

    func togglePause() {
        guard route == .playing, !showCairn, !showDefeat else { return }
        isPaused.toggle()
    }

    func selectClimber(_ id: String) {
        var next = locker
        guard next.select(id) else { return }
        locker = next
        persistLocker()
    }

    func unlockClimber(_ id: String) {
        var next = locker
        let result = next.unlock(id, wallet: wallet)
        locker = next
        embersBalance = wallet.balance
        persistLocker()
        switch result {
        case .unlocked:
            announce("\(ClimberRoster.profile(id: id).name) can take the ridge.")
        case .cannotAfford:
            announce("Not enough Embers yet.")
        case .alreadyOwned, .unknown:
            break
        }
    }

    private func showWeather(_ definition: WeatherDefinition) {
        weatherCallout = definition
        weatherToken += 1
        let token = weatherToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { [weak self] in
            guard let self, self.weatherToken == token else { return }
            self.weatherCallout = nil
        }
    }

    private func advanceTutorial(_ simulation: RidgeSimulation) {
        guard var beat = tutorialBeat, beat != .done else { return }
        let moved = abs(simulation.climber.x - tutorialOriginX) > 30
        let next = TutorialScript.nextBeat(
            beat,
            moved: moved,
            hazardsDefeated: simulation.score.hazardsDefeated,
            elapsedInBeat: simulation.elapsed - tutorialBeatStart,
            charmsOwned: simulation.ownedCharms.count
        )
        if next != beat {
            beat = next
            tutorialBeat = next
            tutorialBeatStart = simulation.elapsed
            if next == .done {
                DispatchQueue.main.async { [weak self] in
                    self?.completeTutorial()
                }
                return
            }
        }
        guard tutorialArmed != beat else { return }
        tutorialArmed = beat
        if beat == .strike {
            simulation.launchPracticeTarget()
        } else if beat == .cairn {
            _ = simulation.presentScriptedCairn(ids: TutorialScript.cairnOfferIDs)
            if case .cairn(let offers) = simulation.phase {
                cairnOffers = offers
                showCairn = true
            }
        }
    }

    private func completeTutorial() {
        guard tutorialBeat != nil else { return }
        tutorialBeat = nil
        markTutorialSeen()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.returnToTitle()
            self.announce("The ridge is yours.")
        }
    }

    private func markTutorialSeen() {
        tutorialSeen = true
        defaults.set(true, forKey: StorageKey.tutorialSeen)
    }

    private func recordDiscoveries(from simulation: RidgeSimulation) {
        var next = discovery
        var changed = false
        for charm in simulation.ownedCharms where next.recordCharm(charm.id) {
            changed = true
        }
        for fusion in simulation.activeFusions where next.recordFusion(fusion.id) {
            changed = true
        }
        guard changed else { return }
        discovery = next
        if let data = try? JSONEncoder().encode(discovery) {
            defaults.set(data, forKey: StorageKey.discovery)
        }
    }

    private func persistLocker() {
        if let data = try? JSONEncoder().encode(locker) {
            defaults.set(data, forKey: StorageKey.locker)
        }
    }

    private func finishRun() {
        guard route == .playing, let session else { return }
        if tutorialBeat != nil {
            completeTutorial()
            return
        }
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
