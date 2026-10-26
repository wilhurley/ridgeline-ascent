import RidgelineCore
import SpriteKit
import SwiftUI

struct RunView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        // Banners stay off this screen. BannerSurface is title and results only.
        ZStack {
            RidgePalette.night.ignoresSafeArea()
            if let scene = app.scene {
                SpriteView(scene: scene, preferredFramesPerSecond: 60)
                    .id(app.runID)
                    .ignoresSafeArea()
            }
            VStack(spacing: 6) {
                hud
                if let weather = app.weatherCallout {
                    weatherCallout(weather)
                }
                Spacer()
                if let prompt = app.tutorialPrompt, !app.showCairn, !app.showDefeat {
                    tutorialBanner(prompt)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            if app.showCairn {
                CairnChoiceView(offers: app.cairnOffers) { id in
                    app.chooseCharm(id)
                }
            }
            if app.showDefeat {
                DefeatCard()
            }
            if app.isPaused, !app.showCairn, !app.showDefeat {
                PauseOverlay()
            }
            if let toast = app.toast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(RidgePalette.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.72))
                        .clipShape(Capsule())
                        .padding(.bottom, 28)
                }
                .allowsHitTesting(false)
            }
        }
    }

    private var hud: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(app.hud.daily ? "Daily Ascent" : app.hud.stageName)
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(app.hud.gear)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(RidgePalette.ice)
                        ForEach(0..<max(app.hud.charmCount, 1), id: \.self) { index in
                            Circle()
                                .fill(index < app.hud.charmCount ? RidgePalette.gold : Color.white.opacity(0.15))
                                .frame(width: 5, height: 5)
                        }
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(app.hud.altitude) m")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                    Text("Score \(app.hud.score)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(RidgePalette.muted)
                        .lineLimit(1)
                }
                Button {
                    app.togglePause()
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(RidgePalette.ink)
                        .frame(width: 32, height: 26)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Pause")
            }
            HStack(spacing: 3) {
                ForEach(app.tagProgress) { progress in
                    let goal = progress.nextThreshold ?? max(progress.count, 2)
                    Text("\(progress.tag.displayName) \(progress.count)/\(goal)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .foregroundStyle(progress.count > 0 ? progress.tag.tint : RidgePalette.muted)
                        .frame(maxWidth: .infinity)
                }
            }
            HStack(spacing: 8) {
                MeterBar(title: "Hold", fraction: app.hud.healthFraction, tint: RidgePalette.ice)
                MeterBar(
                    title: "Avalanche",
                    fraction: app.hud.leadFraction,
                    tint: app.hud.leadFraction < 0.45 ? RidgePalette.danger : RidgePalette.muted
                )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.46))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .foregroundStyle(RidgePalette.ink)
    }

    private func weatherCallout(_ weather: WeatherDefinition) -> some View {
        HStack(spacing: 8) {
            Image(systemName: weather.kind.symbolName)
                .foregroundStyle(RidgePalette.gold)
            Text(weather.name)
                .font(.system(size: 15, weight: .semibold, design: .serif))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.45))
        .clipShape(Capsule())
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
    }

    private func tutorialBanner(_ prompt: String) -> some View {
        HStack(spacing: 12) {
            Text(prompt)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(RidgePalette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Skip") {
                app.skipTutorial()
            }
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(RidgePalette.night)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RidgePalette.gold)
            .clipShape(Capsule())
        }
        .padding(12)
        .background(Color.black.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.bottom, 12)
    }
}

struct PauseOverlay: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Paused")
                        .font(.system(size: 28, weight: .bold, design: .serif))
                    if let weather = app.scene?.simulation.weather {
                        Label(weather.name, systemImage: weather.kind.symbolName)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(RidgePalette.gold)
                    }
                    labeledList("Charms", empty: "No charms yet.", lines: app.runCharms.map { "\($0.name) · \($0.tag.displayName)" })
                    labeledList("Bonuses", empty: "No set bonus yet.", lines: app.runBonuses.map(\.name))
                    labeledList("Fusions", empty: "No fusion yet.", lines: app.runFusions.map(\.name))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tags")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(RidgePalette.muted)
                        ForEach(app.tagProgress.filter { $0.count > 0 }) { progress in
                            let goal = progress.nextThreshold.map(String.init) ?? "set"
                            Text("\(progress.tag.displayName) \(progress.count) · next \(goal)")
                                .foregroundStyle(progress.tag.tint)
                        }
                    }
                    RidgeButton(title: "Resume") {
                        app.togglePause()
                    }
                    RidgeButton(title: "Equipment", filled: false) {
                        app.showEquipment = true
                    }
                }
                .padding(22)
            }
        }
        .foregroundStyle(RidgePalette.ink)
    }

    private func labeledList(_ title: String, empty: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(RidgePalette.muted)
            if lines.isEmpty {
                Text(empty)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(RidgePalette.muted)
            } else {
                ForEach(lines, id: \.self) { line in
                    Text(line)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                }
            }
        }
    }
}

struct DefeatCard: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.62).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("The mountain almost kept you.")
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(RidgePalette.ink)
                Text("One flare can put you back on the ridge. It can be lit once this ascent.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(RidgePalette.muted)
                    .multilineTextAlignment(.center)
                RidgeButton(title: "Flare revive", subtitle: "Rewarded placement") {
                    app.requestRevive()
                }
                RidgeButton(title: "Leave the ridge", filled: false) {
                    app.abandonRun()
                }
            }
            .padding(22)
        }
    }
}

struct RewardPlaceholder: View {
    @EnvironmentObject private var app: AppModel
    let placement: RewardedPlacement

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                Text("Rewarded placement")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(RidgePalette.gold)
                Text(placement.displayName)
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundStyle(RidgePalette.ink)
                Text("No ad plays in this build. Granting the reward is the stand-in for a finished rewarded ad. This is not an interstitial.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(RidgePalette.muted)
                RidgeButton(title: "Grant reward") {
                    app.resolveReward(earned: true)
                }
                RidgeButton(title: "Not now", filled: false) {
                    app.resolveReward(earned: false)
                }
            }
            .padding(22)
            .background(Color(hex: 0x1A242E))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(24)
        }
    }
}
