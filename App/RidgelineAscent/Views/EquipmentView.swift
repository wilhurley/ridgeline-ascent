import RidgelineCore
import SwiftUI

struct EquipmentView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var tab = FieldTab.climbers

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Equipment")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                Spacer()
                Button("Close") { dismiss() }
                    .foregroundStyle(RidgePalette.gold)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FieldTab.allCases) { item in
                        Button(item.title) { tab = item }
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(tab == item ? RidgePalette.ember : Color.white.opacity(0.06))
                            .foregroundStyle(tab == item ? RidgePalette.night : RidgePalette.ink)
                            .clipShape(Capsule())
                    }
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch tab {
                    case .climbers:
                        climbers
                    case .gear:
                        gear
                    case .charms:
                        charms
                    case .hazards:
                        hazards
                    case .weather:
                        weather
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RidgePalette.night.ignoresSafeArea())
        .foregroundStyle(RidgePalette.ink)
    }

    private var climbers: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(ClimberRoster.all) { profile in
                card {
                    Text(profile.name).font(.system(size: 18, weight: .bold, design: .serif))
                    Text(profile.epithet).foregroundStyle(RidgePalette.gold)
                    Text(profile.summary).foregroundStyle(RidgePalette.muted)
                    Text("\(profile.toolName). Climb \(pct(profile.climbMultiplier)), health \(pct(profile.healthMultiplier)), damage \(pct(profile.damageMultiplier)), swing time \(pct(profile.cooldownMultiplier)).")
                    Text(app.locker.isUnlocked(profile.id) ? "Unlocked" : "\(profile.unlockCost) Embers")
                        .foregroundStyle(RidgePalette.ember)
                }
            }
        }
    }

    private var gear: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Numbers for a balanced climb, before charms.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(RidgePalette.muted)
            ForEach(FieldGuide.gear(config: .standard)) { item in
                card {
                    Text(item.style.displayName).font(.system(size: 18, weight: .bold, design: .serif))
                    Text(item.summary)
                    Text("Hit \(ridgeQuantity(item.damage)) · burn \(ridgeQuantity(item.burn)) · every \(ridgeQuantity(item.cooldown))s · range \(ridgeQuantity(item.range)) · targets \(item.targets)")
                        .foregroundStyle(RidgePalette.ice)
                    Text(item.charmNote).foregroundStyle(RidgePalette.muted)
                }
            }
        }
    }

    private var charms: some View {
        let catalog = CharmCatalog.starter
        let found = app.discovery.charmIDs.count
        return VStack(alignment: .leading, spacing: 10) {
            Text("Found \(found) of \(catalog.charms.count) charms")
                .foregroundStyle(RidgePalette.gold)
            ForEach(TagProgress.snapshot(owned: [], catalog: catalog)) { progress in
                card {
                    Text(progress.tag.displayName).foregroundStyle(progress.tag.tint)
                    Text("2 — \(progress.twoPieceName): \(progress.twoPieceEffect)")
                    Text("4 — \(progress.fourPieceName): \(progress.fourPieceEffect)")
                        .foregroundStyle(RidgePalette.muted)
                }
            }
            ForEach(FieldGuide.charms(catalog: catalog, discovered: app.discovery, revealFusions: false)) { charm in
                card {
                    HStack {
                        Text(charm.name).font(.system(size: 17, weight: .semibold, design: .serif))
                        Spacer()
                        Text(charm.discovered ? "Found" : "Not yet")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(charm.discovered ? RidgePalette.gold : RidgePalette.muted)
                    }
                    Text(charm.tag.displayName).foregroundStyle(charm.tag.tint)
                    Text(charm.summary).foregroundStyle(RidgePalette.muted)
                    ForEach(charm.effectLines, id: \.self) { line in
                        Text(line)
                    }
                    ForEach(charm.combinations, id: \.self) { line in
                        Text(line).foregroundStyle(RidgePalette.ice)
                    }
                }
            }
            Text("Fusions")
                .font(.system(size: 20, weight: .bold, design: .serif))
                .padding(.top, 8)
            ForEach(FieldGuide.fusions(catalog: catalog, discovered: app.discovery)) { fusion in
                card {
                    Text(fusion.name).font(.system(size: 17, weight: .semibold, design: .serif))
                    Text(fusion.requirement).foregroundStyle(RidgePalette.gold)
                    Text(fusion.summary).foregroundStyle(RidgePalette.muted)
                }
            }
        }
    }

    private var hazards: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(FieldGuide.hazards()) { hazard in
                card {
                    Text(hazard.name).font(.system(size: 18, weight: .bold, design: .serif))
                    Text(hazard.summary).foregroundStyle(RidgePalette.muted)
                }
            }
        }
    }

    private var weather: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(WeatherTable.all) { item in
                card {
                    Label(item.name, systemImage: item.kind.symbolName)
                        .font(.system(size: 18, weight: .bold, design: .serif))
                    Text(item.summary)
                    if item.boostedTags.isEmpty {
                        Text("No tag bonus.")
                            .foregroundStyle(RidgePalette.muted)
                    } else {
                        Text(item.boostedTags.map { "\($0.displayName) charms +25%" }.joined(separator: ", "))
                            .foregroundStyle(RidgePalette.gold)
                    }
                    Text(item.telegraphsRocks ? "Incoming rocks show a shadow first." : "The ridge stays readable.")
                        .foregroundStyle(RidgePalette.muted)
                }
            }
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            content()
        }
        .font(.system(size: 14, weight: .regular, design: .rounded))
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func pct(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}

private enum FieldTab: String, CaseIterable, Identifiable {
    case climbers, gear, charms, hazards, weather

    var id: String { rawValue }

    var title: String {
        switch self {
        case .climbers: return "Climbers"
        case .gear: return "Gear"
        case .charms: return "Charms"
        case .hazards: return "Hazards"
        case .weather: return "Weather"
        }
    }
}
