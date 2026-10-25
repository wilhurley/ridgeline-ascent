import XCTest
@testable import RidgelineCore

final class CatalogTests: XCTestCase {
    func testStarterCatalogShape() throws {
        let catalog = CharmCatalog.starter
        try catalog.validate()
        XCTAssertEqual(catalog.charms.count, 12)
        XCTAssertEqual(catalog.fusions.count, 2)
        XCTAssertEqual(Set(catalog.charms.map(\.tag)), Set(ElementTag.allCases))

        let counts = Dictionary(grouping: catalog.charms, by: \.tag).mapValues(\.count)
        for tag in ElementTag.allCases {
            XCTAssertGreaterThan(counts[tag] ?? 0, 0)
        }

        let glacial = try XCTUnwrap(catalog.fusions.first { $0.id == "glacial_pyre" })
        XCTAssertEqual(Set(glacial.requires), Set(["rime_edge", "cinder_flare"]))
        let storm = try XCTUnwrap(catalog.fusions.first { $0.id == "stormbind" })
        XCTAssertEqual(Set(storm.requires), Set(["shearwind", "lantern_wisp"]))
    }

    func testOffersAreDistinctAndSkipOwnedCharms() {
        var rng = SplitMix64(seed: 11)
        let first = CharmCatalog.starter.offers(count: 3, excluding: [], rng: &rng)
        XCTAssertEqual(first.count, 3)
        XCTAssertEqual(Set(first.map(\.id)).count, 3)

        let excluded = Set(first.map(\.id))
        let second = CharmCatalog.starter.offers(count: 3, excluding: excluded, rng: &rng)
        XCTAssertEqual(second.count, 3)
        XCTAssertTrue(Set(second.map(\.id)).isDisjoint(with: excluded))
    }

    func testOffersShrinkWhenThePoolIsSmall() {
        var rng = SplitMix64(seed: 3)
        let owned = Set(CharmCatalog.starter.charms.map(\.id).dropLast())
        let offers = CharmCatalog.starter.offers(count: 3, excluding: owned, rng: &rng)
        XCTAssertEqual(offers.count, 1)
    }

    func testEffectRoundTrip() throws {
        let effect = CharmEffect.avalancheDrag(speed: 8)
        let data = try JSONEncoder().encode(effect)
        let decoded = try JSONDecoder().decode(CharmEffect.self, from: data)
        XCTAssertEqual(effect, decoded)
    }

    func testRejectsUnknownEffectType() {
        let data = #"{"type":"interstitial","fraction":1}"#.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(CharmEffect.self, from: data))
    }
}
