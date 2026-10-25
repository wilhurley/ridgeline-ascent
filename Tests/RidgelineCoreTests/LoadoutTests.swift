import XCTest
@testable import RidgelineCore

final class LoadoutTests: XCTestCase {
    func testFractionsStackAndArmorCaps() {
        let config = SimConfig.standard
        let loadout = Loadout.resolve(config: config, effects: [
            .climbSpeed(fraction: 0.10),
            .climbSpeed(fraction: 0.10),
            .contactArmor(fraction: 0.50),
            .contactArmor(fraction: 0.40),
            .attackCooldown(fraction: -0.9),
            .burnDamage(4)
        ])
        XCTAssertEqual(loadout.climbSpeed, config.baseClimbSpeed * 1.2, accuracy: 0.001)
        XCTAssertEqual(loadout.armor, 0.65, accuracy: 0.001)
        XCTAssertEqual(loadout.cooldown, 0.12, accuracy: 0.001)
        XCTAssertEqual(loadout.gearStyle, .flare)
    }

    func testRopeHookWhenExtraTargetsAndNoBurn() {
        let loadout = Loadout.resolve(config: .standard, effects: [.extraTargets(1)])
        XCTAssertEqual(loadout.targets, 2)
        XCTAssertEqual(loadout.gearStyle, .ropeHook)
    }

    func testStarterRimeEdgeRaisesDamage() throws {
        let charm = try XCTUnwrap(CharmCatalog.starter.charm(id: "rime_edge"))
        let loadout = Loadout.resolve(config: .standard, effects: charm.effects)
        XCTAssertGreaterThan(loadout.damage, SimConfig.standard.baseAttackDamage)
    }
}
