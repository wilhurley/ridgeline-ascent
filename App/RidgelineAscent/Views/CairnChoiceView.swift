import RidgelineCore
import SwiftUI

struct CairnChoiceView: View {
    @EnvironmentObject private var app: AppModel
    let offers: [CharmDefinition]
    let choose: (String) -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("Cairn")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(RidgePalette.gold)
                Text("The ridge holds its breath. Choose a trail charm.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(RidgePalette.muted)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 4)
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(offers) { offer in
                            charmCard(offer)
                        }
                    }
                }
            }
            .padding(22)
        }
    }

    private func charmCard(_ offer: CharmDefinition) -> some View {
        let dossier = FieldGuide.charmDossier(
            offer,
            catalog: .starter,
            discovered: app.discovery,
            revealFusions: true
        )
        return Button {
            choose(offer.id)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(offer.tag.tint)
                    .frame(width: 6)
                VStack(alignment: .leading, spacing: 4) {
                    Text(dossier.tag.displayName.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(dossier.tag.tint)
                    Text(dossier.name)
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(RidgePalette.ink)
                    ForEach(dossier.effectLines, id: \.self) { line in
                        Text(line)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(RidgePalette.ink)
                    }
                    ForEach(dossier.combinations, id: \.self) { line in
                        Text(line)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(RidgePalette.ice)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(dossier.name), \(dossier.tag.displayName). \(dossier.effectLines.joined(separator: ". "))")
    }
}
