import RidgelineCore
import SwiftUI

struct TitleView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)
            MountainMark()
                .frame(height: 150)
                .padding(.bottom, 8)
            Text("RIDGELINE")
                .font(.system(size: 40, weight: .bold, design: .serif))
                .tracking(3)
                .foregroundStyle(RidgePalette.ink)
            Text("ASCENT")
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .tracking(8)
                .foregroundStyle(RidgePalette.ember)
                .padding(.bottom, 8)
            Text("Stay ahead of the avalanche.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(RidgePalette.muted)
                .padding(.bottom, 28)

            VStack(spacing: 12) {
                RidgeButton(title: "Begin Ascent", subtitle: "A fresh storm") {
                    app.start(daily: false)
                }
                RidgeButton(title: "Daily Ascent", subtitle: "Same ridge for everyone today", filled: false) {
                    app.start(daily: true)
                }
            }
            .padding(.horizontal, 28)

            HStack(spacing: 18) {
                stat("Embers", "\(app.embersBalance)")
                stat("Best", "\(app.bestAltitude) m")
                stat("Daily", "\(app.bestDaily) m")
            }
            .padding(.top, 22)

            if !app.ownsSummitPack {
                Button {
                    app.showSummitPack = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(SummitPack.displayName)  \(SummitPack.displayPrice)")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                            Text(SummitPack.summary)
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundStyle(RidgePalette.muted)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(RidgePalette.gold)
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)
                .padding(.top, 18)
            }

            Spacer()
            if app.showsBanner {
                BannerSlotView()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
            Text("Ridgeline Apps LLC")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(RidgePalette.muted)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RidgePalette.night.ignoresSafeArea())
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(RidgePalette.ink)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(RidgePalette.muted)
        }
    }
}

struct MountainMark: View {
    var body: some View {
        Canvas { context, size in
            var far = Path()
            far.move(to: CGPoint(x: 0, y: size.height))
            far.addLine(to: CGPoint(x: size.width * 0.18, y: size.height * 0.55))
            far.addLine(to: CGPoint(x: size.width * 0.36, y: size.height * 0.72))
            far.addLine(to: CGPoint(x: size.width * 0.55, y: size.height * 0.28))
            far.addLine(to: CGPoint(x: size.width * 0.74, y: size.height * 0.62))
            far.addLine(to: CGPoint(x: size.width * 0.9, y: size.height * 0.4))
            far.addLine(to: CGPoint(x: size.width, y: size.height * 0.7))
            far.addLine(to: CGPoint(x: size.width, y: size.height))
            far.closeSubpath()
            context.fill(far, with: .color(Color(hex: 0x243140)))

            var near = Path()
            near.move(to: CGPoint(x: 0, y: size.height))
            near.addLine(to: CGPoint(x: size.width * 0.22, y: size.height * 0.62))
            near.addLine(to: CGPoint(x: size.width * 0.48, y: size.height * 0.78))
            near.addLine(to: CGPoint(x: size.width * 0.7, y: size.height * 0.48))
            near.addLine(to: CGPoint(x: size.width, y: size.height * 0.8))
            near.addLine(to: CGPoint(x: size.width, y: size.height))
            near.closeSubpath()
            context.fill(near, with: .color(Color(hex: 0x1A242E)))

            let ember = Path(ellipseIn: CGRect(x: size.width * 0.55 - 5, y: size.height * 0.28 - 16, width: 10, height: 10))
            context.fill(ember, with: .color(RidgePalette.ember))
        }
        .accessibilityHidden(true)
    }
}
