import XCTest
@testable import RidgelineCore

final class RockfallTests: XCTestCase {
    func testSlabSplitsIntoSmallerRocksAndPebblesDoNot() {
        let slab = makeSim { config in
            config.forcedWeather = .clear
            config.baseAttackDamage = 80
            config.baseAttackCooldown = 0.05
        }
        _ = slab.testingSpawnHazard(
            kind: .slab,
            x: slab.climber.x,
            y: slab.climber.y + 70,
            health: 20,
            radius: 27
        )
        slab.tick(dt: 1.0 / 60.0)
        XCTAssertEqual(slab.score.hazardsDefeated, 1)
        XCTAssertEqual(slab.hazards.filter { $0.kind == .boulder }.count, 1)
        XCTAssertEqual(slab.hazards.filter { $0.kind == .pebble }.count, 1)
        XCTAssertFalse(slab.hazards.contains { $0.kind == .slab })

        let pebble = makeSim { config in
            config.forcedWeather = .clear
            config.baseAttackDamage = 80
            config.baseAttackCooldown = 0.05
        }
        _ = pebble.testingSpawnHazard(
            kind: .pebble,
            x: pebble.climber.x,
            y: pebble.climber.y + 40,
            health: 8,
            radius: 7
        )
        pebble.tick(dt: 1.0 / 60.0)
        XCTAssertTrue(pebble.hazards.isEmpty)
        XCTAssertEqual(pebble.score.hazardsDefeated, 1)
    }

    func testScreeRocksAreFasterAndLighterThanSlabs() throws {
        let early = DifficultyCurve.sample(stage: .screeApproach, timeInStage: 0, climbTime: 0)
        XCTAssertFalse(early.allowedKinds.contains(.slab))
        XCTAssertFalse(early.allowedKinds.contains(.iceWraith))
        let shelf = DifficultyCurve.sample(stage: .iceShelf, timeInStage: 0, climbTime: 0)
        XCTAssertTrue(shelf.allowedKinds.contains(.slab))
        let pebble = try XCTUnwrap(Rockfall.spec(.pebble, stage: .screeApproach))
        let slab = try XCTUnwrap(Rockfall.spec(.slab, stage: .screeApproach))
        XCTAssertGreaterThan(pebble.speedMultiplier, slab.speedMultiplier)
        XCTAssertGreaterThan(slab.health, pebble.health * 3)
        XCTAssertEqual(slab.splitsInto, [.boulder, .pebble])
        XCTAssertTrue(pebble.splitsInto.isEmpty)
    }

    func testLowVisibilityTelegraphsRocksBeforeTheyExist() throws {
        let sim = makeSim { config in
            config.forcedWeather = .blizzard
            config.spawnsEnabled = true
            config.cairnInterval = 10_000
            config.baseAttackDamage = 0
            config.baseMaxHealth = 5_000
            config.stageDurations = [30, 30, 30]
        }
        sim.tick(dt: 0.7)
        XCTAssertFalse(sim.warnings.isEmpty)
        XCTAssertTrue(sim.warnings.allSatisfy { $0.kind.isRock })
        XCTAssertTrue(sim.hazards.isEmpty)
        let warning = try XCTUnwrap(sim.warnings.first)
        let baseLead = WeatherTable.definition(for: .blizzard).warningLead
        XCTAssertGreaterThan(warning.timeRemaining, baseLead)
        XCTAssertLessThan(warning.timeRemaining, baseLead + OpeningEase.telegraphBonus)
        sim.tick(dt: 1.1)
        XCTAssertFalse(sim.hazards.isEmpty)
        XCTAssertTrue(sim.hazards.allSatisfy { $0.kind.isRock })
    }
}

final class WeatherTests: XCTestCase {
    func testStageWeatherIsStableForASeed() {
        let first = WeatherTable.kind(stage: .screeApproach, seed: 42)
        XCTAssertEqual(first, WeatherTable.kind(stage: .screeApproach, seed: 42))
        var seen = Set<WeatherKind>()
        for seed in 1...48 {
            seen.insert(WeatherTable.kind(stage: .iceShelf, seed: UInt64(seed)))
        }
        XCTAssertEqual(seen, Set(WeatherKind.allCases))

        let sim = RidgeSimulation(config: SimConfig(seed: 42, spawnsEnabled: false))
        XCTAssertEqual(sim.weather.kind, WeatherTable.kind(stage: .screeApproach, seed: 42))
    }

    func testFrostHitsHarderInABlizzardAndGaleClimbsFasterInTheNightStorm() {
        let clear = makeSim { $0.forcedWeather = .clear }
        let snow = makeSim { $0.forcedWeather = .blizzard }
        XCTAssertTrue(clear.testingGrantCharm(id: "rime_edge"))
        XCTAssertTrue(snow.testingGrantCharm(id: "rime_edge"))
        let base = SimConfig.standard.baseAttackDamage
        XCTAssertEqual(clear.loadout.damage, base * 1.20, accuracy: 0.001)
        XCTAssertEqual(snow.loadout.damage, base * 1.25, accuracy: 0.001)

        let still = makeSim { $0.forcedWeather = .clear }
        let storm = makeSim { $0.forcedWeather = .nightStorm }
        XCTAssertTrue(still.testingGrantCharm(id: "updraft_strap"))
        XCTAssertTrue(storm.testingGrantCharm(id: "updraft_strap"))
        XCTAssertEqual(still.loadout.climbSpeed, SimConfig.standard.baseClimbSpeed * 1.12, accuracy: 0.001)
        XCTAssertEqual(storm.loadout.climbSpeed, SimConfig.standard.baseClimbSpeed * 1.15, accuracy: 0.001)

        let rain = makeSim { $0.forcedWeather = .rain }
        XCTAssertTrue(rain.testingGrantCharm(id: "rime_edge"))
        XCTAssertEqual(rain.loadout.damage, clear.loadout.damage, accuracy: 0.001)
    }

    func testRainKeepsSlidingAfterTheThumbLifts() {
        let rain = makeSim { $0.forcedWeather = .rain }
        let clear = makeSim { $0.forcedWeather = .clear }
        rain.setSteer(normalizedX: 1)
        clear.setSteer(normalizedX: 1)
        rain.tick(dt: 0.4)
        clear.tick(dt: 0.4)
        let rainMark = rain.climber.x
        let clearMark = clear.climber.x
        rain.setSteer(normalizedX: normalized(rain))
        clear.setSteer(normalizedX: normalized(clear))
        rain.tick(dt: 0.3)
        clear.tick(dt: 0.3)
        XCTAssertGreaterThan(rain.climber.x - rainMark, 8)
        XCTAssertLessThan(abs(clear.climber.x - clearMark), 2)
    }

    func testBlizzardGustsMoveACenteredClimber() {
        let snow = makeSim { $0.forcedWeather = .blizzard }
        let clear = makeSim { $0.forcedWeather = .clear }
        let origin = snow.climber.x
        snow.tick(dt: 2)
        clear.tick(dt: 2)
        XCTAssertGreaterThan(abs(snow.climber.x - origin), 4)
        XCTAssertEqual(clear.climber.x, origin, accuracy: 0.001)
    }

    func testLightningOpensAHiddenRock() throws {
        let sim = makeSim { $0.forcedWeather = .nightStorm }
        let id = sim.testingSpawnHazard(
            kind: .boulder,
            x: sim.climber.x,
            y: sim.climber.y + 900,
            health: 40
        )
        let hidden = try XCTUnwrap(sim.hazards.first { $0.id == id })
        XCTAssertTrue(sim.isConcealed(hidden))
        sim.tick(dt: 4.3)
        let later = try XCTUnwrap(sim.hazards.first { $0.id == id })
        XCTAssertGreaterThan(sim.lightningRemaining, 0)
        XCTAssertFalse(sim.isConcealed(later))
    }

    private func normalized(_ sim: RidgeSimulation) -> Double {
        let margin = 18.0
        let span = sim.config.ridgeWidth - margin * 2
        return min(1, max(0, (sim.climber.x - margin) / span))
    }
}

final class ClimberTests: XCTestCase {
    func testGuideIsFreeAndTheOthersCostEmbers() {
        XCTAssertEqual(ClimberRoster.guide.unlockCost, 0)
        XCTAssertEqual(ClimberRoster.scout.unlockCost, 30)
        XCTAssertEqual(ClimberRoster.hauler.unlockCost, 50)
        var locker = ClimberLocker.fresh
        XCTAssertTrue(locker.isUnlocked(ClimberRoster.guide.id))
        XCTAssertFalse(locker.select(ClimberRoster.scout.id))

        let poor = EmbersWallet(balance: 10)
        XCTAssertEqual(locker.unlock(ClimberRoster.hauler.id, wallet: poor), .cannotAfford)
        XCTAssertEqual(poor.balance, 10)

        let wallet = EmbersWallet(balance: 80)
        XCTAssertEqual(locker.unlock(ClimberRoster.scout.id, wallet: wallet), .unlocked)
        XCTAssertEqual(wallet.balance, 50)
        XCTAssertEqual(locker.unlock(ClimberRoster.scout.id, wallet: wallet), .alreadyOwned)
        XCTAssertEqual(wallet.balance, 50)
        XCTAssertTrue(locker.select(ClimberRoster.scout.id))
        XCTAssertEqual(locker.selectedID, ClimberRoster.scout.id)
    }

    func testProfilesChangeTheOpeningLoadout() {
        let guideConfig = ClimberRoster.applying(ClimberRoster.guide, to: SimConfig(forcedWeather: .clear))
        let scoutConfig = ClimberRoster.applying(ClimberRoster.scout, to: SimConfig(forcedWeather: .clear))
        let haulerConfig = ClimberRoster.applying(ClimberRoster.hauler, to: SimConfig(forcedWeather: .clear))
        let guide = Loadout.resolve(config: guideConfig, effects: [])
        let scout = Loadout.resolve(config: scoutConfig, effects: [])
        let hauler = Loadout.resolve(config: haulerConfig, effects: [])
        XCTAssertEqual(guide.gearStyle, .iceAxe)
        XCTAssertEqual(scout.gearStyle, .flare)
        XCTAssertGreaterThan(scout.climbSpeed, guide.climbSpeed)
        XCTAssertLessThan(scout.maxHealth, guide.maxHealth)
        XCTAssertLessThan(hauler.climbSpeed, guide.climbSpeed)
        XCTAssertGreaterThan(hauler.maxHealth, guide.maxHealth)
        XCTAssertGreaterThan(hauler.armor, 0)
        XCTAssertEqual(hauler.gearStyle, .iceAxe)
    }

    func testSkinsDoNotChangeTheClimb() {
        for skin in ClimberRoster.skins {
            XCTAssertTrue(skin.isCosmeticOnly)
            XCTAssertFalse(ClimberRoster.affectsRules(skin))
        }
        XCTAssertNotNil(ClimberRoster.skins.first { $0.id == ClimberRoster.highCampCoatID }?.productID)
        var locker = ClimberLocker.fresh
        XCTAssertFalse(locker.equip(ClimberRoster.highCampCoatID))
        let before = ClimberRoster.applying(ClimberRoster.guide, to: .standard)
        let wallet = EmbersWallet(balance: 40)
        XCTAssertTrue(locker.grantCosmetic(ClimberRoster.highCampCoatID))
        XCTAssertEqual(wallet.balance, 40)
        XCTAssertTrue(locker.equip(ClimberRoster.highCampCoatID))
        let after = ClimberRoster.applying(ClimberRoster.guide, to: .standard)
        XCTAssertEqual(before.baseClimbSpeed, after.baseClimbSpeed)
        XCTAssertEqual(before.baseMaxHealth, after.baseMaxHealth)
        XCTAssertEqual(before.baseAttackDamage, after.baseAttackDamage)
        XCTAssertEqual(before.bonusBurn, after.bonusBurn)
    }
}

final class FieldGuideTests: XCTestCase {
    func testCharmLinesCarryNumbersAndHideUndiscoveredFusions() throws {
        let charm = try XCTUnwrap(CharmCatalog.starter.charm(id: "rime_edge"))
        XCTAssertEqual(charm.effects.first?.playerLine, "Attack damage +20%")
        let open = FieldGuide.charmDossier(charm, catalog: .starter, discovered: DiscoveryLog(), revealFusions: true)
        XCTAssertTrue(open.combinations.contains { $0.contains("Cinder Flare") && $0.contains("Glacial Pyre") })
        let hidden = FieldGuide.charmDossier(charm, catalog: .starter, discovered: DiscoveryLog(), revealFusions: false)
        XCTAssertTrue(hidden.combinations.contains { $0.contains("???") })
        var log = DiscoveryLog()
        XCTAssertTrue(log.recordFusion("glacial_pyre"))
        let found = FieldGuide.fusions(catalog: .starter, discovered: log).first { $0.id == "glacial_pyre" }
        XCTAssertEqual(found?.name, "Glacial Pyre")
        let other = FieldGuide.fusions(catalog: .starter, discovered: log).first { $0.id == "stormbind" }
        XCTAssertEqual(other?.name, "???")
    }

    func testTagProgressAndGearNumbersComeFromTheRules() throws {
        let catalog = CharmCatalog.starter
        let one = TagProgress.snapshot(owned: [catalog.charm(id: "rime_edge")!], catalog: catalog)
        let frost = try XCTUnwrap(one.first { $0.tag == .frost })
        XCTAssertEqual(frost.count, 1)
        XCTAssertEqual(frost.nextThreshold, 2)
        XCTAssertNil(frost.activeBonusName)
        let pair = TagProgress.snapshot(
            owned: [catalog.charm(id: "rime_edge")!, catalog.charm(id: "sleet_ward")!],
            catalog: catalog
        )
        let paired = try XCTUnwrap(pair.first { $0.tag == .frost })
        XCTAssertEqual(paired.nextThreshold, 4)
        XCTAssertEqual(paired.activeBonusName, "Rime Pair")

        let gear = FieldGuide.gear(config: .standard)
        let axe = try XCTUnwrap(gear.first { $0.style == .iceAxe })
        let flare = try XCTUnwrap(gear.first { $0.style == .flare })
        let hook = try XCTUnwrap(gear.first { $0.style == .ropeHook })
        XCTAssertEqual(axe.damage, SimConfig.standard.baseAttackDamage, accuracy: 0.001)
        XCTAssertEqual(axe.targets, 1)
        XCTAssertGreaterThan(flare.burn, 0)
        XCTAssertEqual(hook.targets, 2)
        XCTAssertEqual(FieldGuide.hazards().map(\.id).count, 7)
        XCTAssertEqual(WeatherTable.all.count, 4)
    }

    func testEmberBreakdownAddsUp() {
        var score = RunScore()
        score.altitude = 500
        score.hazardsDefeated = 4
        score.cairnsClaimed = 2
        score.stagesCleared = 1
        score.summitReached = true
        let breakdown = score.emberBreakdown(yieldFraction: 0.2)
        XCTAssertEqual(breakdown.fromRidge + breakdown.summitBonus + breakdown.charmYield, breakdown.total)
        XCTAssertEqual(breakdown.total, 30)
        XCTAssertEqual(breakdown.summitBonus, 20)
    }
}

final class TutorialTests: XCTestCase {
    func testBeatsAdvanceOnlyWhenThePlayerDoesTheThing() {
        XCTAssertEqual(TutorialScript.nextBeat(.steer, moved: false, hazardsDefeated: 0, elapsedInBeat: 9, charmsOwned: 0), .steer)
        XCTAssertEqual(TutorialScript.nextBeat(.steer, moved: true, hazardsDefeated: 0, elapsedInBeat: 0, charmsOwned: 0), .strike)
        XCTAssertEqual(TutorialScript.nextBeat(.strike, moved: true, hazardsDefeated: 0, elapsedInBeat: 5, charmsOwned: 0), .strike)
        XCTAssertEqual(TutorialScript.nextBeat(.strike, moved: true, hazardsDefeated: 1, elapsedInBeat: 0.2, charmsOwned: 0), .avalanche)
        XCTAssertEqual(TutorialScript.nextBeat(.avalanche, moved: true, hazardsDefeated: 1, elapsedInBeat: 3.9, charmsOwned: 0), .avalanche)
        XCTAssertEqual(TutorialScript.nextBeat(.avalanche, moved: true, hazardsDefeated: 1, elapsedInBeat: 4, charmsOwned: 0), .cairn)
        XCTAssertEqual(TutorialScript.nextBeat(.cairn, moved: true, hazardsDefeated: 1, elapsedInBeat: 8, charmsOwned: 0), .cairn)
        XCTAssertEqual(TutorialScript.nextBeat(.cairn, moved: true, hazardsDefeated: 1, elapsedInBeat: 0, charmsOwned: 1), .setBonus)
        XCTAssertEqual(TutorialScript.nextBeat(.setBonus, moved: true, hazardsDefeated: 1, elapsedInBeat: 3.1, charmsOwned: 1), .setBonus)
        XCTAssertEqual(TutorialScript.nextBeat(.setBonus, moved: true, hazardsDefeated: 1, elapsedInBeat: 3.2, charmsOwned: 1), .done)
        XCTAssertTrue(TutorialScript.prompt(.setBonus, tag: .frost).contains("Frost"))
        XCTAssertEqual(TutorialScript.cairnOfferIDs.count, 3)
    }

    func testPracticeTargetAndScriptedCairn() {
        let sim = RidgeSimulation(config: TutorialScript.configuration(seed: 3))
        sim.launchPracticeTarget()
        XCTAssertEqual(sim.hazards.first?.kind, .pebble)
        XCTAssertTrue(sim.presentScriptedCairn(ids: TutorialScript.cairnOfferIDs))
        guard case .cairn(let offers) = sim.phase else {
            return XCTFail("Expected the scripted cairn")
        }
        XCTAssertEqual(offers.map(\.id), TutorialScript.cairnOfferIDs)
    }
}
