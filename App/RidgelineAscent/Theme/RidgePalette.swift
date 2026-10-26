import RidgelineCore
import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

enum RidgeSK {
    static func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> UIColor {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}

enum RidgePalette {
    static let night = Color(hex: 0x10161E)
    static let ink = Color(hex: 0xE7EEF4)
    static let muted = Color(hex: 0x9AA8B5)
    static let ember = Color(hex: 0xE07A3D)
    static let gold = Color(hex: 0xD4A054)
    static let ice = Color(hex: 0x8FCBD6)
    static let danger = Color(hex: 0xD85A4A)
    static let pine = Color(hex: 0x1E3A34)
}

extension ElementTag {
    var tint: Color {
        switch self {
        case .frost: return Color(hex: 0xB7D7E8)
        case .ember: return Color(hex: 0xE07A3D)
        case .gale: return Color(hex: 0x7FB3C8)
        case .stone: return Color(hex: 0xC4B29A)
        case .spirit: return Color(hex: 0xC7B4E3)
        }
    }
}
