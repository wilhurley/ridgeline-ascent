# Ridgeline Ascent

A portrait iPhone action roguelite by **Ridgeline Apps LLC**. One thumb drags anywhere to steer a climber up a storm-lashed ridge. An avalanche climbs behind them. Ice axe, flare, and rope-hook swings fire on their own. Every half-minute a cairn offers three trail charms. Charms carry Frost, Ember, Gale, Stone, or Spirit. Two and four of a tag open set bonuses. Two pairs fuse.

This repository is the first playable slice: the rules live in a pure Swift package, and a SpriteKit / SwiftUI app plays a full run on top.

## Layout

```
Package.swift                  RidgelineCore, tested with `swift test`
Sources/RidgelineCore/         Run simulation, charms, scoring, Embers, ad policy
Tests/RidgelineCoreTests/      Unit tests. No SpriteKit.
App/RidgelineAscent/           iOS 17 app: menus, SpriteKit ridge, service hooks
RidgelineAscent.xcodeproj      Shared scheme. Open this on a Mac. No XcodeGen.
```

`RidgelineCore` does not import SpriteKit, SwiftUI, or UIKit. The app imports the package and draws whatever the simulation reports.

```
Title -> climb -> cairn (3 charms) -> next stage -> death or summit -> results -> climb again
```

Stages are Scree Approach, Ice Shelf, and Crow's Eave, about 70 seconds each, then the Cornice Tyrant. A cairn opens every 36 seconds of climbing and pauses the ridge until a charm is chosen. The avalanche tracks a gap that shrinks over the run and closes during the boss. Hits slow the climber and do not slow the avalanche.

## Charms

Definitions live in `Sources/RidgelineCore/Resources/catalog.json`.

Twelve starter charms cover all five tags. The starter set has two or three charms per tag, so a 2-piece bonus can happen in one run. A 4-piece bonus is in the rules and waits for more charms.

Fusions are not offered at cairns. They wake when both charms are owned:

| Fusion | Pair |
| --- | --- |
| Glacial Pyre | Rime Edge + Cinder Flare |
| Stormbind | Shearwind + Lantern Wisp |

Embers are the only meta currency. They are credited from the run score when the ascent ends. Nothing in this slice sells Embers. `EmbersWallet.debit` is the seam for a later Base Camp.

## Ads, Summit Pack, Game Center, daily runs

Hard rule: there is no interstitial, pop-up, or app-open ad, and no banner during a climb.

| Surface | What exists |
| --- | --- |
| Title and results | One banner slot. Removed by the Summit Pack. |
| Death | Optional rewarded revive, once per run, only after the player asks. |
| Results | Optional rewarded double Embers, once per run, only after the player asks. |

`BannerSurface` is `title` and `results`. `RewardedPlacement` is `revive` and `doubleRewards`. There is no other ad type to call.

The Summit Pack product id is `com.ridgelineapps.ridgelineascent.summitpack` at **$3.99**. It only removes banners. StoreKit is not linked. The in-game sheet grants the entitlement on the device so the banner can be checked.

Game Center ids:

- `com.ridgelineapps.ridgelineascent.leaderboard.altitude`
- `com.ridgelineapps.ridgelineascent.leaderboard.daily`

Scores are queued by `GameCenterHook`. Sign-in is not linked.

Daily Ascent uses `DailyRun.seed(for:)`, a stable FNV-1a of the UTC civil date, and submits to the daily board.

Replacement points, with the SDK still absent:

- `App/RidgelineAscent/Services/ServiceHooks.swift` — rewarded ads, StoreKit, Game Center
- `App/RidgelineAscent/Audio/SoundBoard.swift` — swap the bundled tones for scored audio
- `SimEffect` — the simulation's juice and sound hook. The scene turns those into shake, flashes, particles, and cues.

## Logic tests

From the repository root, with Swift 5.9 or newer:

```bash
swift test
```

That builds `RidgelineCore` and runs the XCTest suite: catalog shape, set bonuses, fusions, steering, avalanche death, auto-attacks, cairns, stage and boss flow, deterministic seeds, Embers, once-per-run revive and double rewards, the banner rule, and the daily seed. SpriteKit is not involved.

## Run on a Mac

Xcode 16 or newer (this project was prepared for Xcode 26). iOS 17 or newer. iPhone only, portrait. The project is already generated. XcodeGen and Homebrew are not required.

Bundle id: `com.ridgelineapps.ridgelineascent`

Open `RidgelineAscent.xcodeproj`, choose the **RidgelineAscent** scheme and an **iPhone 17** simulator, and press Run.

Simulator build from the repository root, with code signing already disabled in the project:

```bash
xcodebuild -project RidgelineAscent.xcodeproj -scheme RidgelineAscent -destination 'platform=iOS Simulator,name=iPhone 17' build
```

A device build needs signing turned back on and a team selected. The Summit Pack, rewarded placements, and Game Center hooks are local stand-ins until those SDKs are added.

## What this slice does not do yet

- Base Camp spending Embers
- Enough charms for a 4-piece set inside one run
- More fusions, stage modifiers, and a deeper boss pattern
- Original illustrated art and scored audio (the ridge is drawn from shapes; the sounds are short tones)
- A real rewarded-ad SDK, StoreKit 2, or Game Center authentication
- Daily rules beyond the shared seed and leaderboard

Verified here: `swift test` on Linux (Swift 6.4.1). Not verified here: the `xcodebuild` command above, or a hands-on run in the iPhone 17 simulator. Those need the Mac.
