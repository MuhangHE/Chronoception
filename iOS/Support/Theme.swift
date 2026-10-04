import SwiftUI
import UIKit

/// Claude's palette: warm ivory paper, near-black ink and a clay-orange accent,
/// each with a dark-mode counterpart.
enum Theme {
    /// Page background.
    static let canvas = Color(light: 0xF0EEE6, dark: 0x262624)
    /// Cards and list rows.
    static let surface = Color(light: 0xFAF9F5, dark: 0x30302E)
    static let ink = Color(light: 0x141413, dark: 0xF5F4EE)
    static let secondaryInk = Color(light: 0x73726C, dark: 0xA6A39A)
    static let hairline = Color(light: 0xE3E1D7, dark: 0x41403C)
    /// Clay: primary actions and highlights.
    static let accent = Color(light: 0xC96442, dark: 0xD97757)
    /// Text on an accent fill.
    static let onAccent = Color(light: 0xFAF9F5, dark: 0xFAF9F5)
    /// Brick red for deleting and for errors; the system red is too loud here.
    static let danger = Color(light: 0xB5402F, dark: 0xE2735F)
}

extension Color {
    /// A color that follows light and dark mode.
    nonisolated init(light: UInt32, dark: UInt32) {
        let light = uiColor(light)
        let dark = uiColor(dark)
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

private nonisolated func uiColor(_ hex: UInt32) -> UIColor {
    UIColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}

extension View {
    /// Ivory page behind a List or Form.
    func paperBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(Theme.canvas)
    }

    /// Paper rows with warm separators; apply to a List row or Section.
    func paperRows() -> some View {
        listRowBackground(Theme.surface)
            .listRowSeparatorTint(Theme.hairline)
    }
}

/// Claude's primary button: clay fill, ivory text.
struct ClayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.onAccent)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Theme.accent, in: .rect(cornerRadius: 10))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
