import RidgelineCore
import SwiftUI

struct HowToPlayView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    private let cards: [GuideCard] = [
        GuideCard(
            title: "Steer",
            line: "Drag anywhere. The climber steps to that lane.",
            detail: "The tool swings on its own."
        ),
        GuideCard(
            title: "Avalanche",
            line: "Stay above the white.",
            detail: "A hit slows you. The snow does not slow down."
        ),
        GuideCard(
            title: "Cairns",
            line: "The ridge pauses. Pick one charm.",
            detail: "It stays for this ascent."
        ),
        GuideCard(
            title: "Tags",
            line: "Frost, Ember, Gale, Stone, Spirit.",
            detail: "Two of a tag open a bonus. Four open a stronger one. Some pairs fuse."
        ),
        GuideCard(
            title: "Embers",
            line: "The climb pays you.",
            detail: "Spend Embers on climbers. Nothing sells them."
        )
    ]

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("How to Play")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                Spacer()
                Button("Close") { dismiss() }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(RidgePalette.gold)
            }
            TabView(selection: $page) {
                ForEach(cards.indices, id: \.self) { index in
                    GuideCardView(card: cards[index], index: index)
                        .tag(index)
                        .padding(.horizontal, 4)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(maxHeight: 420)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(RidgePalette.night.ignoresSafeArea())
        .foregroundStyle(RidgePalette.ink)
    }
}

private struct GuideCard {
    let title: String
    let line: String
    let detail: String
}

private struct GuideCardView: View {
    let card: GuideCard
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GuideSketch(index: index)
                .frame(height: 140)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            Text(card.title)
                .font(.system(size: 26, weight: .bold, design: .serif))
            Text(card.line)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
            Text(card.detail)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(RidgePalette.muted)
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct GuideSketch: View {
    let index: Int

    var body: some View {
        Canvas { context, size in
            switch index {
            case 0:
                var path = Path()
                path.move(to: CGPoint(x: size.width * 0.2, y: size.height * 0.7))
                path.addQuadCurve(
                    to: CGPoint(x: size.width * 0.75, y: size.height * 0.35),
                    control: CGPoint(x: size.width * 0.55, y: size.height * 0.8)
                )
                context.stroke(path, with: .color(RidgePalette.gold), lineWidth: 3)
                let dot = Path(ellipseIn: CGRect(x: size.width * 0.72, y: size.height * 0.28, width: 14, height: 14))
                context.fill(dot, with: .color(RidgePalette.ember))
            case 1:
                var snow = Path()
                snow.addRect(CGRect(x: 0, y: size.height * 0.62, width: size.width, height: size.height * 0.38))
                context.fill(snow, with: .color(RidgePalette.ice.opacity(0.85)))
                let climber = Path(ellipseIn: CGRect(x: size.width * 0.46, y: size.height * 0.28, width: 16, height: 22))
                context.fill(climber, with: .color(RidgePalette.ember))
            case 2:
                for column in 0..<3 {
                    let x = size.width * (0.18 + CGFloat(column) * 0.28)
                    let stone = Path(roundedRect: CGRect(x: x, y: size.height * 0.28, width: 54, height: 70), cornerRadius: 8)
                    context.fill(stone, with: .color(Color.white.opacity(0.08)))
                    let pip = Path(ellipseIn: CGRect(x: x + 20, y: size.height * 0.38, width: 12, height: 12))
                    context.fill(pip, with: .color(RidgePalette.gold))
                }
            case 3:
                let tags = ElementTag.allCases
                for (offset, tag) in tags.enumerated() {
                    let x = 18 + CGFloat(offset) * ((size.width - 36) / 5)
                    let bar = Path(roundedRect: CGRect(x: x, y: size.height * 0.35, width: 28, height: 48), cornerRadius: 6)
                    context.fill(bar, with: .color(tag.tint))
                }
            default:
                let coin = Path(ellipseIn: CGRect(x: size.width * 0.4, y: size.height * 0.28, width: 48, height: 48))
                context.fill(coin, with: .color(RidgePalette.ember))
            }
        }
        .accessibilityHidden(true)
    }
}
