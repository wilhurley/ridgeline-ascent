import SwiftUI
import RidgelineCore

struct ResultsView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(app.summary?.end.headline ?? "The ridge rests.")
                        .font(.system(size: 30, weight: .bold, design: .serif))
                        .foregroundStyle(RidgePalette.ink)
                    if app.newBest {
                        Text("New best altitude")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(RidgePalette.gold)
                    }
                    if let summary = app.summary {
                        VStack(spacing: 8) {
                            row("Stage", summary.stageName)
                            row("Altitude", "\(Int(summary.score.altitude.rounded(.down))) m")
                            row("Hazards", "\(summary.score.hazardsDefeated)")
                            row("Cairns", "\(summary.score.cairnsClaimed)")
                            row("Stages cleared", "\(summary.score.stagesCleared)")
                            row("Score", "\(summary.score.points)")
                            row("Embers earned", "\(app.embersGranted)")
                            row("Embers carried", "\(app.embersBalance)")
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        if !summary.charmNames.isEmpty {
                            Text(summary.charmNames.joined(separator: " · "))
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(RidgePalette.ice)
                        }
                        if !summary.fusionNames.isEmpty {
                            Text(summary.fusionNames.joined(separator: " · "))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(RidgePalette.ember)
                        }
                    }
                    Text(app.leaderboardNote)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(RidgePalette.muted)

                    if app.canOfferDouble {
                        RidgeButton(
                            title: app.doubledThisRun ? "Embers doubled" : "Double Embers",
                            subtitle: app.doubledThisRun ? nil : "Rewarded placement, once",
                            filled: !app.doubledThisRun
                        ) {
                            if !app.doubledThisRun {
                                app.requestDoubleRewards()
                            }
                        }
                        .disabled(app.doubledThisRun)
                    }
                    RidgeButton(title: "Climb again") {
                        app.start(daily: app.dailyActive)
                    }
                    RidgeButton(title: "Trailhead", filled: false) {
                        app.returnToTitle()
                    }
                    if !app.ownsSummitPack {
                        Button {
                            app.showSummitPack = true
                        } label: {
                            Text("\(SummitPack.displayName) \(SummitPack.displayPrice)")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(RidgePalette.gold)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(24)
            }
            if app.showsBanner {
                BannerSlotView()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RidgePalette.night.ignoresSafeArea())
        .foregroundStyle(RidgePalette.ink)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(RidgePalette.muted)
            Spacer()
            Text(value)
        }
        .font(.system(size: 15, weight: .medium, design: .rounded))
    }
}

struct SummitPackSheet: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(SummitPack.displayName)
                .font(.system(size: 28, weight: .bold, design: .serif))
            Text(SummitPack.displayPrice)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(RidgePalette.ember)
            Text(SummitPack.summary)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(RidgePalette.muted)
            Text("StoreKit is not linked yet. Granting the pack on this device removes the banner slots so the loop can be checked. It does not add Embers.")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(RidgePalette.muted)
            RidgeButton(title: "Grant Summit Pack") {
                app.purchaseSummitPack()
            }
            RidgeButton(title: "Restore", filled: false) {
                app.restoreSummitPack()
            }
            Button("Close") {
                app.showSummitPack = false
            }
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundStyle(RidgePalette.muted)
            .frame(maxWidth: .infinity)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RidgePalette.night.ignoresSafeArea())
        .foregroundStyle(RidgePalette.ink)
    }
}
