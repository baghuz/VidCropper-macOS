import SwiftUI

enum Theme {
    static let background = Color(hex: 0x0B0C10)
    static let canvas = Color(hex: 0x08090C)
    static let panel = Color(hex: 0x121419)
    static let card = Color(hex: 0x1A1D24)
    static let cardHover = Color(hex: 0x242832)
    static let border = Color.white.opacity(0.075)
    static let borderStrong = Color.white.opacity(0.15)

    static let accent = Color(hex: 0xC8F65C)
    static let accentSoft = Color(hex: 0xC8F65C).opacity(0.14)
    static let accentDark = Color(hex: 0x9CCB32)
    static let danger = Color(hex: 0xFF7272)

    static let textPrimary = Color(hex: 0xF4F5F7)
    static let textSecondary = Color(hex: 0x9CA2AE)
    static let textTertiary = Color(hex: 0x666C78)

    static let cornerRadius: CGFloat = 12
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

extension Font {
    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

struct PanelDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.border)
            .frame(height: 1)
    }
}

struct SectionLabel: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.ui(10, weight: .bold))
            .tracking(1.5)
            .foregroundStyle(Theme.textTertiary)
    }
}

struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
