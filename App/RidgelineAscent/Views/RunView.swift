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
            VStack(spacing: 8) {
                hud
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            if app.showCairn {
                CairnChoiceView(offers: app.cairnOffers) { id in
                    app.chooseCharm(id)
                }
            }
            if app.showDefeat {
                DefeatCard()
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.hud.daily ? "Daily Ascent" : app.hud.stageName)
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                    Text(app.hud.gear)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(RidgePalette.ice)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(app.hud.altitude) m")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Text("Score \(app.hud.score)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(RidgePalette.muted)
                }
            }
            HStack(spacing: 4) {
                ForEach(0..<max(app.hud.charmCount, 1), id: \.self) { index in
                    Circle()
                        .fill(index < app.hud.charmCount ? RidgePalette.gold : Color.white.opacity(0.15))
                        .frame(width: 7, height: 7)
                }
                Spacer()
            }
            MeterBar(title: "Hold", fraction: app.hud.healthFraction, tint: RidgePalette.ice)
            MeterBar(
                title: "Avalanche",
                fraction: app.hud.leadFraction,
                tint: app.hud.leadFraction < 0.45 ? RidgePalette.danger : RidgePalette.muted
            )
        }
        .padding(12)
        .background(Color.black.opacity(0.38))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .foregroundStyle(RidgePalette.ink)
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
