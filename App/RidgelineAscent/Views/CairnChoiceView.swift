import RidgelineCore
import SwiftUI

struct CairnChoiceView: View {
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
                ForEach(offers) { offer in
                    Button {
                        choose(offer.id)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(offer.tag.tint)
                                .frame(width: 6)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(offer.tag.displayName.uppercased())
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(offer.tag.tint)
                                Text(offer.name)
                                    .font(.system(size: 18, weight: .semibold, design: .serif))
                                    .foregroundStyle(RidgePalette.ink)
                                Text(offer.summary)
                                    .font(.system(size: 13, weight: .regular, design: .rounded))
                                    .foregroundStyle(RidgePalette.muted)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(offer.name), \(offer.tag.displayName). \(offer.summary)")
                }
            }
            .padding(22)
        }
    }
}
