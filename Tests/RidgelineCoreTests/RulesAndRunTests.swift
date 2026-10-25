import XCTest
@testable import RidgelineCore

final class DifficultyTests: XCTestCase {
    func testLaterStagesAreHarsher() {
        let early = DifficultyCurve.sample(stage: .screeApproach, timeInStage: 0, climbTime: 0)
        let late = DifficultyCurve.sample(stage: .crowsEave, timeInStage: 40, climbTime: 160)
        XCTAssertLessThan(late.spawnInterval, early.spawnInterval)
        XCTAssertGreaterThan(late.avalancheBonus, early.avalancheBonus)
        XCTAssertEqual(early.allowedKinds, [.pebble, .boulder])
        XCTAssertEqual(late.allowedKinds, [.pebble, .boulder, .slab, .iceWraith, .stormCrow])
        let boss = DifficultyCurve.sample(stage: .theCornice, timeInStage: 0, climbTime: 200)
        XCTAssertFalse(boss.allowedKinds.contains(.corniceTyrant))
        XCTAssertTrue(boss.allowedKinds.contains(.stormCrow))
    }

    func testCleanClimbTracksAShrinkingGap() {
        let sim = makeSim { config in
            config.spawnsEnabled = false
            config.cairnInterval = 10_000
        }
        let start = sim.lead
        sim.tick(dt: 30)
        XCTAssertEqual(sim.phase, .climbing)
        XCTAssertLessThan(sim.lead, start)
        XCTAssertGreaterThan(sim.lead, 140)
    }
}

final class SimulationTests: XCTestCase {
    func testSteerMovesAndStaysOnTheRidge() {
        let sim = makeSim { $0.spawnsEnabled = false }
        let start = sim.climber.x
        sim.setSteer(normalizedX: 1)
        sim.tick(dt: 0.5)
        XCTAssertGreaterThan(sim.climber.x, start)
        sim.setSteer(normalizedX: 0)
        let peaked = sim.climber.x
        sim.tick(dt: 0.5)
        XCTAssertLessThan(sim.climber.x, peaked)
        sim.setSteer(normalizedX: 1)
        sim.tick(dt: 5)
        XCTAssertLessThanOrEqual(sim.climber.x, sim.config.ridgeWidth - 18)
        XCTAssertGreaterThanOrEqual(sim.climber.x, 18)
    }

    func testAvalancheCatchEndsTheRun() {
        let sim = makeSim { config in
            config.spawnsEnabled = false
            config.startingLead = 30
            config.extraAvalancheSpeed = 500
            config.cairnInterval = 10_000
        }
        sim.tick(dt: 0.3)
        XCTAssertEqual(sim.phase, .defeated(.avalanche))
        let y = sim.climber.y
        sim.tick(dt: 1)
        XCTAssertEqual(sim.climber.y, y)
    }

    func testContactDamageCanEndTheRunWithoutScoringAKill() {
        let sim = makeSim { $0.spawnsEnabled = false }
        sim.testingSetHealth(8)
        _ = sim.testingSpawnHazard(
            kind: .boulder,
            x: sim.climber.x,
            y: sim.climber.y,
            health: 40,
            contactDamage: 20
        )
        sim.tick(dt: 1.0 / 60.0)
        XCTAssertEqual(sim.phase, .defeated(.struckDown))
        XCTAssertEqual(sim.score.hazardsDefeated, 0)
    }

    func testArmorReducesContactDamage() {
        let naked = makeSim { $0.spawnsEnabled = false }
        let warded = makeSim { $0.spawnsEnabled = false }
        XCTAssertTrue(warded.testingGrantCharm(id: "sleet_ward"))
        naked.testingSetHealth(100)
        warded.testingSetHealth(100)
        for sim in [naked, warded] {
            _ = sim.testingSpawnHazard(
                kind: .boulder,
                x: sim.climber.x,
                y: sim.climber.y,
                health: 80,
                contactDamage: 10
            )
            sim.tick(dt: 1.0 / 60.0)
        }
        XCTAssertGreaterThan(warded.climber.health, naked.climber.health)
    }

    func testAutoAttackDamagesAndCanDefeatAHazard() {
        let sim = makeSim { $0.spawnsEnabled = false }
        let id = sim.testingSpawnHazard(
            kind: .boulder,
            x: sim.climber.x,
            y: sim.climber.y + 50,
            health: 30
        )
        sim.tick(dt: 1.0 / 60.0)
        let rock = sim.hazards.first { $0.id == id }
        XCTAssertNotNil(rock)
        XCTAssertLessThan(rock?.health ?? 99, 30)

        let finisher = makeSim { $0.spawnsEnabled = false }
        _ = finisher.testingSpawnHazard(
            kind: .iceWraith,
            x: finisher.climber.x,
            y: finisher.climber.y + 50,
            health: 10
        )
        finisher.tick(dt: 1.0 / 60.0)
        XCTAssertTrue(finisher.hazards.isEmpty)
        XCTAssertEqual(finisher.score.hazardsDefeated, 1)
    }

    func testCairnPausesAndChoiceResumes() {
        let sim = makeSim { config in
            config.spawnsEnabled = false
            config.cairnInterval = 2
            config.stageDurations = [10_000, 10_000, 10_000]
        }
        sim.tick(dt: 2.05)
        guard case .cairn(let offers) = sim.phase else {
            return XCTFail("Expected a cairn, got \(sim.phase)")
        }
        XCTAssertEqual(offers.count, 3)
        let frozen = sim.climber.y
        sim.tick(dt: 2)
        XCTAssertEqual(sim.climber.y, frozen)
        XCTAssertFalse(sim.chooseCharm(id: "not-a-charm"))
        XCTAssertTrue(sim.chooseCharm(id: offers[0].id))
        XCTAssertEqual(sim.phase, .climbing)
        XCTAssertEqual(sim.ownedCharms.map(\.id), [offers[0].id])
        sim.tick(dt: 0.4)
        XCTAssertGreaterThan(sim.climber.y, frozen)
    }

    func testLaterCairnsDoNotRepeatOwnedCharms() {
        let sim = makeSim { config in
            config.spawnsEnabled = false
            config.cairnInterval = 1.2
            config.stageDurations = [10_000, 10_000, 10_000]
        }
        var owned = Set<String>()
        for _ in 0..<4 {
            sim.tick(dt: 1.3)
            guard case .cairn(let offers) = sim.phase else {
                return XCTFail("Expected a cairn")
            }
            XCTAssertTrue(owned.isDisjoint(with: offers.map(\.id)))
            XCTAssertTrue(sim.chooseCharm(id: offers[0].id))
            owned.insert(offers[0].id)
        }
        XCTAssertEqual(sim.ownedCharms.count, 4)
    }

    func testSetBonusAndFusionUnlockFromOwnedCharms() {
        let sim = makeSim { $0.spawnsEnabled = false }
        XCTAssertTrue(sim.testingGrantCharm(id: "rime_edge"))
        XCTAssertTrue(sim.activeSetBonuses.isEmpty)
        XCTAssertTrue(sim.testingGrantCharm(id: "sleet_ward"))
        XCTAssertTrue(sim.activeSetBonuses.contains { $0.id == "frost_2" })
        XCTAssertFalse(sim.activeSetBonuses.contains { $0.threshold == 4 })
        XCTAssertTrue(sim.testingGrantCharm(id: "cinder_flare"))
        XCTAssertTrue(sim.activeFusions.contains { $0.id == "glacial_pyre" })
        XCTAssertGreaterThan(sim.loadout.burnDamage, 5)
    }

    func testFourPieceRequiresFourCharms() {
        let frost = (1...4).map { index in
            CharmDefinition(
                id: "frost_\(index)",
                name: "Frost \(index)",
                tag: .frost,
                summary: "Test charm",
                effects: [.attackDamage(fraction: 0.01)]
            )
        }
        let bonuses = CharmCatalog.starter.setBonuses.filter { $0.tag == .frost }
        let catalog = CharmCatalog(charms: frost, fusions: [], setBonuses: bonuses)
        let sim = RidgeSimulation(config: SimConfig(spawnsEnabled: false), catalog: catalog)
        for charm in frost {
            XCTAssertTrue(sim.testingGrantCharm(id: charm.id))
        }
        XCTAssertTrue(sim.activeSetBonuses.contains { $0.threshold == 2 })
        XCTAssertTrue(sim.activeSetBonuses.contains { $0.threshold == 4 })
    }

    func testVigilSparkHealsAtTheCairnThatGrantsIt() {
        let spark = CharmDefinition(
            id: "vigil_spark",
            name: "Vigil Spark",
            tag: .spirit,
            summary: "Rest",
            effects: [.healOnCairn(12)]
        )
        let filler = (1...3).map { index in
            CharmDefinition(
                id: "filler_\(index)",
                name: "Filler \(index)",
                tag: .stone,
                summary: "Stone",
                effects: [.maxHealth(1)]
            )
        }
        let catalog = CharmCatalog(charms: [spark] + filler, fusions: [], setBonuses: [])
        var config = SimConfig.standard
        config.spawnsEnabled = false
        config.cairnInterval = 1
        config.stageDurations = [10_000, 10_000, 10_000]
        let sim = RidgeSimulation(config: config, catalog: catalog)
        sim.tick(dt: 1.05)
        guard case .cairn(let offers) = sim.phase else {
            return XCTFail("Expected cairn")
        }
        guard let sparkOffer = offers.first(where: { $0.id == "vigil_spark" }) else {
            // The shuffle might not include it. Grant path is covered elsewhere;
            // force the known offer by choosing only if present, otherwise spin cairns.
            return spinForSpark(sim)
        }
        sim.testingSetHealth(40)
        XCTAssertTrue(sim.chooseCharm(id: sparkOffer.id))
        XCTAssertEqual(sim.climber.health, 52, accuracy: 0.001)
    }

    private func spinForSpark(_ sim: RidgeSimulation) {
        for _ in 0..<6 {
            if case .cairn(let offers) = sim.phase, offers.contains(where: { $0.id == "vigil_spark" }) {
                sim.testingSetHealth(40)
                XCTAssertTrue(sim.chooseCharm(id: "vigil_spark"))
                XCTAssertEqual(sim.climber.health, 52, accuracy: 0.001)
                return
            }
            if case .cairn(let offers) = sim.phase {
                _ = sim.chooseCharm(id: offers[0].id)
            }
            sim.tick(dt: 1.05)
        }
        XCTFail("Vigil Spark was never offered")
    }

    func testStageProgressionWakesTheCornice() {
        let sim = makeSim { config in
            config.spawnsEnabled = false
            config.stageDurations = [0.4, 0.4, 0.4]
            config.cairnInterval = 10_000
            config.baseAttackDamage = 0
        }
        sim.tick(dt: 0.45)
        XCTAssertEqual(sim.stage, .iceShelf)
        sim.tick(dt: 0.45)
        XCTAssertEqual(sim.stage, .crowsEave)
        sim.tick(dt: 0.45)
        XCTAssertEqual(sim.stage, .theCornice)
        XCTAssertEqual(sim.phase, .boss)
        XCTAssertEqual(sim.score.stagesCleared, 3)
        XCTAssertEqual(sim.hazards.filter { $0.kind == .corniceTyrant }.count, 1)
    }

    func testBossDefeatReachesTheSummit() {
        let sim = makeSim { config in
            config.spawnsEnabled = false
            config.stageDurations = [0.12, 0.12, 0.12]
            config.cairnInterval = 10_000
            config.bossHealth = 30
            config.baseAttackDamage = 80
            config.baseAttackCooldown = 0.15
            config.baseAttackRange = 400
        }
        for _ in 0..<400 where sim.phase != .summit {
            sim.tick(dt: 0.05)
        }
        XCTAssertEqual(sim.phase, .summit)
        XCTAssertTrue(sim.score.summitReached)
        XCTAssertFalse(sim.hazards.contains { $0.kind == .corniceTyrant })
    }

    func testSameSeedProducesTheSameRidge() {
        func run(_ seed: UInt64) -> (Double, Int, Int, RunPhase) {
            var config = SimConfig.standard
            config.seed = seed
            config.stageDurations = [8, 8, 8]
            config.cairnInterval = 3
            let sim = RidgeSimulation(config: config)
            for _ in 0..<200 {
                sim.setSteer(normalizedX: 0.25)
                sim.tick(dt: 0.05)
                if case .cairn(let offers) = sim.phase, let first = offers.first {
                    _ = sim.chooseCharm(id: first.id)
                }
            }
            return (sim.climber.y, sim.hazards.count, sim.score.hazardsDefeated, sim.phase)
        }
        XCTAssertEqual(run(42).0, run(42).0)
        XCTAssertEqual(run(42).1, run(42).1)
        XCTAssertEqual(run(42).2, run(42).2)
        XCTAssertEqual(run(42).3, run(42).3)
        XCTAssertNotEqual(run(42).0, run(99).0)
    }

    func testStageOneSpawnsOnlyRocks() {
        let sim = makeSim { config in
            config.seed = 5
            config.spawnsEnabled = true
            config.stageDurations = [30, 30, 30]
            config.cairnInterval = 10_000
            config.baseAttackDamage = 0
            config.baseMaxHealth = 5_000
        }
        sim.tick(dt: 6)
        XCTAssertFalse(sim.hazards.isEmpty)
        XCTAssertTrue(sim.hazards.allSatisfy { $0.kind == .pebble || $0.kind == .boulder })
    }
}

final class EconomyTests: XCTestCase {
    func testScoreAndEmberFormula() {
        var score = RunScore()
        score.altitude = 500
        score.hazardsDefeated = 4
        score.cairnsClaimed = 2
        score.stagesCleared = 1
        XCTAssertEqual(score.points, 830)
        XCTAssertEqual(score.embers, 3)
        score.summitReached = true
        XCTAssertEqual(score.points, 1330)
        XCTAssertEqual(score.embers, 25)
        XCTAssertEqual(score.earnedEmbers(yieldFraction: 0.2), 30)
        XCTAssertEqual(score.earnedEmbers(yieldFraction: 0), 25)
    }

    func testWalletCreditsDebitsAndIgnoresBadAmounts() {
        var saved: [Int] = []
        let wallet = EmbersWallet(balance: 5) { saved.append($0) }
        wallet.credit(0)
        wallet.credit(-3)
        XCTAssertEqual(wallet.balance, 5)
        wallet.credit(7)
        XCTAssertEqual(wallet.balance, 12)
        XCTAssertFalse(wallet.debit(20))
        XCTAssertEqual(wallet.balance, 12)
        XCTAssertFalse(wallet.debit(0))
        XCTAssertTrue(wallet.debit(4))
        XCTAssertEqual(wallet.balance, 8)
        XCTAssertEqual(saved, [12, 8])
    }
}

final class SessionTests: XCTestCase {
    func testSettlePaysOnceAndDoubleRewardsPayOnce() {
        let wallet = EmbersWallet()
        let ads = ScriptedAds(results: [.earned, .earned, .earned])
        let boards = ScriptedBoards()
        let sim = makeSim { config in
            config.spawnsEnabled = false
            config.cairnInterval = 10_000
            config.stageDurations = [10_000, 10_000, 10_000]
        }
        let session = RunSession(
            simulation: sim,
            daily: false,
            wallet: wallet,
            ownsSummitPack: false,
            ads: ads,
            leaderboards: boards
        )
        XCTAssertNil(session.settleIfNeeded())
        var early: DoubleRewardOutcome?
        session.requestDoubleRewards { early = $0 }
        XCTAssertEqual(early, .runStillActive)

        sim.tick(dt: 4)
        sim.testingSetExtraAvalancheSpeed(8_000)
        sim.tick(dt: 0.3)
        XCTAssertEqual(sim.phase, .defeated(.avalanche))
        let summary = session.settleIfNeeded()
        XCTAssertGreaterThan(summary?.embersEarned ?? 0, 0)
        XCTAssertEqual(wallet.balance, summary?.embersEarned)
        XCTAssertEqual(session.settleIfNeeded()?.embersEarned, summary?.embersEarned)
        XCTAssertEqual(wallet.balance, summary?.embersEarned)
        XCTAssertEqual(boards.submissions.map(\.1), [.bestAltitude])

        var doubled: DoubleRewardOutcome?
        session.requestDoubleRewards { doubled = $0 }
        XCTAssertEqual(doubled, .doubled(extraEmbers: summary?.embersEarned ?? -1))
        XCTAssertEqual(wallet.balance, (summary?.embersEarned ?? 0) * 2)

        var third: DoubleRewardOutcome?
        session.requestDoubleRewards { third = $0 }
        XCTAssertEqual(third, .unavailable)
        XCTAssertEqual(wallet.balance, (summary?.embersEarned ?? 0) * 2)
        XCTAssertEqual(ads.placements, [.doubleRewards])
    }

    func testReviveIsOncePerRunAndDoesNotPayEarly() {
        let wallet = EmbersWallet(balance: 3)
        let ads = ScriptedAds(results: [.dismissed, .earned])
        let boards = ScriptedBoards()
        let sim = makeSim { config in
            config.spawnsEnabled = false
            config.startingLead = 25
            config.extraAvalancheSpeed = 700
            config.cairnInterval = 10_000
        }
        let session = RunSession(
            simulation: sim,
            daily: true,
            wallet: wallet,
            ownsSummitPack: false,
            ads: ads,
            leaderboards: boards
        )
        sim.tick(dt: 0.3)
        XCTAssertTrue(session.canOfferRevive)
        var declined: ReviveOutcome?
        session.requestRevive { declined = $0 }
        XCTAssertEqual(declined, .adDeclined)
        XCTAssertEqual(sim.phase, .defeated(.avalanche))
        XCTAssertTrue(session.canOfferRevive)

        var revived: ReviveOutcome?
        session.requestRevive { revived = $0 }
        XCTAssertEqual(revived, .revived)
        XCTAssertNotEqual(sim.phase, .defeated(.avalanche))
        XCTAssertEqual(wallet.balance, 3)
        XCTAssertFalse(session.canOfferRevive)

        sim.testingSetExtraAvalancheSpeed(8_000)
        sim.tick(dt: 0.4)
        XCTAssertEqual(sim.phase, .defeated(.avalanche))
        var blocked: ReviveOutcome?
        session.requestRevive { blocked = $0 }
        XCTAssertEqual(blocked, .unavailable)
        XCTAssertEqual(ads.placements, [.revive, .revive])
        // The second successful presentation is the earned one. The third request
        // never reaches the ad hook.
        XCTAssertEqual(ads.placements.count, 2)

        let summary = session.settleIfNeeded()
        XCTAssertEqual(wallet.balance, 3 + (summary?.embersEarned ?? 0))
        XCTAssertEqual(boards.submissions.map(\.1), [.dailyAscent])
        var afterSettle: ReviveOutcome?
        session.requestRevive { afterSettle = $0 }
        XCTAssertEqual(afterSettle, .unavailable)
    }

    func testSummitPaysABonus() {
        let wallet = EmbersWallet()
        let ads = ScriptedAds(results: [])
        let boards = ScriptedBoards()
        let sim = makeSim { config in
            config.spawnsEnabled = false
            config.stageDurations = [0.12, 0.12, 0.12]
            config.cairnInterval = 10_000
            config.bossHealth = 30
            config.baseAttackDamage = 80
            config.baseAttackRange = 400
            config.baseAttackCooldown = 0.15
        }
        let session = RunSession(
            simulation: sim,
            daily: false,
            wallet: wallet,
            ownsSummitPack: true,
            ads: ads,
            leaderboards: boards
        )
        for _ in 0..<400 where sim.phase != .summit {
            sim.tick(dt: 0.05)
        }
        let summary = session.settleIfNeeded()
        XCTAssertEqual(summary?.end, .summit)
        XCTAssertGreaterThan(summary?.embersEarned ?? 0, 20)
        XCTAssertEqual(wallet.balance, summary?.embersEarned)
        XCTAssertFalse(session.monetization.showsBanner(on: .results))
    }
}

final class MonetizationPolicyTests: XCTestCase {
    func testBannerSurfacesAreOnlyTitleAndResults() {
        XCTAssertEqual(BannerSurface.allCases, [.title, .results])
        for surface in BannerSurface.allCases {
            switch surface {
            case .title, .results:
                break
            }
        }
    }

    func testRewardedPlacementsAreOptInAndNotInterstitial() {
        XCTAssertEqual(RewardedPlacement.allCases, [.revive, .doubleRewards])
        let names = RewardedPlacement.allCases.map(\.rawValue) + BannerSurface.allCases.map(\.rawValue)
        for name in names {
            XCTAssertFalse(name.contains("interstitial"))
            XCTAssertFalse(name.contains("popup"))
            XCTAssertFalse(name.contains("app_open"))
        }
    }

    func testSummitPackRemovesBannersAndDoesNotMintEmbers() {
        XCTAssertEqual(SummitPack.displayPrice, "$3.99")
        XCTAssertEqual(SummitPack.productID, "com.ridgelineapps.ridgelineascent.summitpack")
        var state = RunMonetizationState(ownsSummitPack: false)
        XCTAssertTrue(state.showsBanner(on: .title))
        XCTAssertTrue(state.showsBanner(on: .results))
        state.ownsSummitPack = true
        XCTAssertFalse(state.showsBanner(on: .title))
        XCTAssertFalse(state.showsBanner(on: .results))
    }
}

final class DailyRunTests: XCTestCase {
    func testDailySeedIsStableAndDateSpecific() {
        XCTAssertEqual(DailyRun.seed(year: 2026, month: 10, day: 25), 727_745_151_927_052_948)
        XCTAssertEqual(
            DailyRun.seed(year: 2026, month: 10, day: 25),
            DailyRun.seed(year: 2026, month: 10, day: 25)
        )
        XCTAssertNotEqual(
            DailyRun.seed(year: 2026, month: 10, day: 25),
            DailyRun.seed(year: 2026, month: 10, day: 26)
        )
        var calendar = DailyRun.utcCalendar
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 23))!
        XCTAssertEqual(DailyRun.seed(for: date, calendar: calendar), DailyRun.seed(year: 2026, month: 10, day: 25))
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        _ = calendar
    }
}

func makeSim(_ tweak: (inout SimConfig) -> Void = { _ in }) -> RidgeSimulation {
    var config = SimConfig.standard
    config.spawnsEnabled = false
    config.forcedWeather = .clear
    tweak(&config)
    return RidgeSimulation(config: config)
}

final class ScriptedAds: RewardedAdServing {
    var results: [RewardedAdResult]
    var placements: [RewardedPlacement] = []

    init(results: [RewardedAdResult]) {
        self.results = results
    }

    func show(placement: RewardedPlacement, completion: @escaping (RewardedAdResult) -> Void) {
        placements.append(placement)
        let result = results.isEmpty ? RewardedAdResult.unavailable : results.removeFirst()
        completion(result)
    }
}

final class ScriptedBoards: LeaderboardSubmitting {
    var submissions: [(Int, LeaderboardID)] = []

    func submit(score: Int, leaderboard: LeaderboardID) {
        submissions.append((score, leaderboard))
    }
}
