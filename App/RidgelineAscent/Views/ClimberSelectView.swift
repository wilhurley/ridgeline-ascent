import RidgelineCore
import SwiftUI

struct ClimberSelectView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Climbers")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                Spacer()
                Button("Close") { dismiss() }
                    .foregroundStyle(RidgePalette.gold)
            }
            Text("\(app.embersBalance) Embers")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(RidgePalette.ember)
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(ClimberRoster.all) { profile in
                        climberCard(profile)
                    }
                    Text("Painted coats can be offered later. They change the cloth only, never speed, health, or the swing.")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(RidgePalette.muted)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RidgePalette.night.ignoresSafeArea())
        .foregroundStyle(RidgePalette.ink)
    }

    private func climberCard(_ profile: ClimberProfile) -> some View {
        let unlocked = app.locker.isUnlocked(profile.id)
        let selected = app.locker.selectedID == profile.id
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(.system(size: 20, weight: .bold, design: .serif))
                    Text(profile.epithet)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(RidgePalette.gold)
                }
                Spacer()
                if selected {
                    Text("Selected")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(RidgePalette.night)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RidgePalette.ember)
                        .clipShape(Capsule())
                }
            }
            Text(profile.summary)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(RidgePalette.muted)
            Text("\(profile.toolName) · climb \(percent(profile.climbMultiplier)) · health \(percent(profile.healthMultiplier)) · damage \(percent(profile.damageMultiplier))")
                .font(.system(size: 13, weight: .medium, design: .rounded))
            if unlocked {
                Button(selected ? "On the ridge" : "Climb as \(profile.name)") {
                    app.selectClimber(profile.id)
                }
                .buttonStyle(.plain)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(RidgePalette.gold)
            } else {
                Button("Unlock for \(profile.unlockCost) Embers") {
                    app.unlockClimber(profile.id)
                }
                .buttonStyle(.plain)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(app.embersBalance >= profile.unlockCost ? RidgePalette.gold : RidgePalette.muted)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(selected ? 0.08 : 0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}
