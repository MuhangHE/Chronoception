import SwiftUI
import WidgetKit

extension Color {
    /// Claude's clay, as on the icon and the watch.
    static let clay = Color(red: 0xD9 / 255, green: 0x77 / 255, blue: 0x57 / 255)
}

/// The app's mark, as on its icon: two rounded triangles, tip to tip. The upper one is
/// clay, and takes the accent color when the system tints the widget.
struct HourglassMark: View {
    /// The lower triangle's color.
    var bottom: Color = .primary

    var body: some View {
        ZStack {
            HourglassHalf(isUpper: true)
                .fill(Color.clay)
                .widgetAccentable()
            HourglassHalf(isUpper: false)
                .fill(bottom)
        }
        .aspectRatio(HourglassHalf.size.width / HourglassHalf.size.height, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// One triangle of the mark, in the proportions of `scripts/render-app-icon.swift`.
private struct HourglassHalf: Shape {
    /// The whole mark's size on the 1024-point icon.
    static let size = CGSize(width: 460, height: 576)

    let isUpper: Bool

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width / Self.size.width, rect.height / Self.size.height)
        let halfWidth = 230 * scale
        let edge = 288 * scale // from the center to the flat side
        let neck = 26 * scale // from the center to the tip
        let corner = 44 * scale
        // SwiftUI's y grows downward.
        let direction: CGFloat = isUpper ? -1 : 1
        let left = CGPoint(x: rect.midX - halfWidth, y: rect.midY + direction * edge)
        let right = CGPoint(x: rect.midX + halfWidth, y: rect.midY + direction * edge)
        let tip = CGPoint(x: rect.midX, y: rect.midY + direction * neck)

        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: left.y))
        path.addArc(tangent1End: right, tangent2End: tip, radius: corner)
        path.addArc(tangent1End: tip, tangent2End: left, radius: corner)
        path.addArc(tangent1End: left, tangent2End: right, radius: corner)
        path.closeSubpath()
        return path
    }
}
