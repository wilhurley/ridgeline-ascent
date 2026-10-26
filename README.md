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
First launch -> short practice ascent (skippable; replay from the title)
Title -> climb -> cairn (3 charms) -> next stage and weather -> death or summit -> results
```

The first launch starts a short practice ascent: drag to steer, watch the tool swing, stay above the avalanche, pick a charm, and see a tag count. Skip returns to the title and the practice does not pay Embers. It runs again only from **Practice the first ascent**.

Stages are Scree Approach, Ice Shelf, and Crow's Eave, about 70 seconds each, then the Cornice Tyrant. A cairn opens every 36 seconds of climbing and pauses the ridge until a charm is chosen. The avalanche tracks a gap that shrinks over the run and closes during the boss. Hits slow the climber and do not slow the avalanche.

Each stage rolls one weather from the run seed (the daily seed uses the same roll): Clear, Rain, Blizzard, or Night Storm. Rain keeps your steps sliding and strengthens Stone. Blizzard shortens the view, gusts sideways, and strengthens Frost. Night Storm hides distant rocks until lightning, and strengthens Gale. When the view is short, incoming rocks show a shadow before they appear. The name and icon show for a moment when the weather changes.

Rocks come in three sizes. Pebbles are small and fast. Boulders are the middle. Slabs are slow, take several hits, and split into a boulder and a pebble when the tool breaks them.

Three climbers start with different tools and pace. Sera Quinn, the guide, is free and carries an ice axe. Pell Ash, the scout, costs 30 Embers and starts with a flare. Bram Holt, the hauler, costs 50 Embers, climbs slower, and hits harder. Unlocking spends Embers already earned. Painted coats are data only: a skin cannot change speed, health, or damage, and none are for sale yet.

The backdrop is a painted portrait for each weather (`backdrop_clear`, `backdrop_rain`, `backdrop_blizzard`, `backdrop_night` in the asset catalog). It covers the screen, drifts a few points as you climb, and crossfades when the weather changes. A soft dark vignette sits over the painting so hazards stay readable, and a plain ridge edge sits under the climber. The avalanche is still a churning cloud. Climbers are silhouettes with a climbing bob. `ClimberRendering` is the seam for a later sprite sheet.

**How to Play** is five short cards on the title. **Equipment** (title and pause) lists climbers, the three tools with their numbers, every charm, the five tags and their 2/4 bonuses, fusions as `???` until that fusion has been in a run, the hazards, and the weather. Cairn cards show the charm name, tag, effect numbers, and what it combines with. The climb HUD shows tag progress. Pause lists the charms, bonuses, and fusions on this ascent. Results break Embers into ridge, summit, and charm yield.

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

That builds `RidgelineCore` and runs the XCTest suite: catalog shape, set bonuses, fusions, steering, avalanche death, auto-attacks, cairns, stage and boss flow, deterministic seeds, Embers, once-per-run revive and double rewards, the banner rule, the daily seed, rock sizes and slab splits, weather rolls and tag boosts, climber unlocks, the field guide, and the practice beats. SpriteKit is not involved.

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

- A camp that spends Embers on anything besides the two locked climbers
- Enough charms for a 4-piece set inside one run
- More fusions and a deeper boss pattern
- Higher-resolution backdrop paintings (these are 720×1280) and sprite-sheet climbers. The sounds are still short tones.
- Selling a cosmetic coat (the high-camp coat id is reserved and does not change the rules)
- A real rewarded-ad SDK, StoreKit 2, or Game Center authentication
- Daily rules beyond the shared seed, the weather that seed rolls, and the leaderboard

Verified here: `swift test` on Linux (Swift 6.4.1). Not verified here: the `xcodebuild` command above, or a hands-on run in the iPhone 17 simulator. Those need the Mac.
