import SwiftUI

struct GameTheme {
    let name: String
    let tileFill: Color
    let tileBorder: Color
    let hoverBorder: Color
    let selectedBorder: Color
    let highlightBorder: Color
    let matchLine: Color
    let matchLineGlow: Color

    static let `default` = GameTheme(
        name: "默认蓝白",
        tileFill: .blue.opacity(0.08),
        tileBorder: .blue.opacity(0.2),
        hoverBorder: .white.opacity(0.9),
        selectedBorder: .orange,
        highlightBorder: .green.opacity(0.9),
        matchLine: .yellow,
        matchLineGlow: .orange
    )

    static let dark = GameTheme(
        name: "暗黑霓虹",
        tileFill: .purple.opacity(0.15),
        tileBorder: .purple.opacity(0.4),
        hoverBorder: .cyan.opacity(0.9),
        selectedBorder: .pink,
        highlightBorder: .green.opacity(0.9),
        matchLine: .cyan,
        matchLineGlow: .blue
    )
}
