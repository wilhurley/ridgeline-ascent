import SwiftUI

func ridgeQuantity(_ value: Double) -> String {
    if abs(value - value.rounded()) < 0.05 {
        return String(Int(value.rounded()))
    }
    let tenths = Int((value * 10).rounded())
    let whole = tenths / 10
    let fraction = abs(tenths % 10)
    return "\(whole).\(fraction)"
}

struct RidgeButton: View {
    let title: String
    var subtitle: String?
    var filled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .opacity(0.78)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .foregroundStyle(filled ? Color(hex: 0x1A140F) : RidgePalette.ink)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(filled ? RidgePalette.ember : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(filled ? 0 : 0.14), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct MeterBar: View {
    let title: String
    let fraction: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(RidgePalette.muted)
                .lineLimit(1)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(tint)
                        .frame(width: max(CGFloat(4), proxy.size.width * CGFloat(fraction)))
                }
            }
            .frame(height: 5)
        }
    }
}

struct BannerSlotView: View {
    var body: some View {
        VStack(spacing: 2) {
            Text("Banner slot")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
            Text("Placeholder — no ad SDK linked")
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(RidgePalette.muted)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityLabel("Banner placeholder")
    }
}
