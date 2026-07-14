import SwiftUI

/// 挂件皮肤定义
struct WidgetSkin: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let price: Int          // 0 = 免费
    let description: String

    // 外观属性
    let backgroundColor: String    // hex color
    let foregroundColor: String    // hex color
    let accentColor: String        // hex color
    let fontName: String           // system font design
    let borderStyle: String        // "none", "rounded", "shadow"
    let badgeIcon: String          // SF Symbol name
    let tagShape: String           // "pill", "rect", "circle"
    var imageName: String? = nil // 自定义图片

    var bgColor: Color { Color(hex: backgroundColor) }
    var fgColor: Color { Color(hex: foregroundColor) }
    var accent: Color { Color(hex: accentColor) }

    static let all: [WidgetSkin] = [
        .defaultSkin,
        .neon,
        .pixel,
        .cat,
        .golden,
        .astro,
    ]

    static let defaultSkin = WidgetSkin(
        id: "default",
        name: "经典拉链",
        price: 0,
        description: "简洁的拉链标签，永远免费",
        backgroundColor: "#1a1a2e",
        foregroundColor: "#e0e0e0",
        accentColor: "#f0c040",
        fontName: "default",
        borderStyle: "rounded",
        badgeIcon: "tag.fill",
        tagShape: "pill"
    )

    static let neon = WidgetSkin(
        id: "neon",
        name: "霓虹灯管",
        price: 3000,
        description: "赛博朋克霓虹光效",
        backgroundColor: "#0d0221",
        foregroundColor: "#ff00ff",
        accentColor: "#00ffff",
        fontName: "monospaced",
        borderStyle: "shadow",
        badgeIcon: "bolt.fill",
        tagShape: "rect"
    )

    static let pixel = WidgetSkin(
        id: "pixel",
        name: "像素风",
        price: 5000,
        description: "8-bit 复古像素美学",
        backgroundColor: "#2d2d2d",
        foregroundColor: "#98fb98",
        accentColor: "#ff6b6b",
        fontName: "monospaced",
        borderStyle: "none",
        badgeIcon: "square.grid.3x3.fill",
        tagShape: "rect"
    )

    static let cat = WidgetSkin(
        id: "cat",
        name: "小猫爪印",
        price: 5000,
        description: "可爱猫咪主题",
        backgroundColor: "#fff5f5",
        foregroundColor: "#d6336c",
        accentColor: "#ff922b",
        fontName: "rounded",
        borderStyle: "rounded",
        badgeIcon: "pawprint.fill",
        tagShape: "circle"
    )

    static let golden = WidgetSkin(
        id: "golden",
        name: "金色 VIP",
        price: 10000,
        description: "尊贵金色，身份的象征",
        backgroundColor: "#1a1a1a",
        foregroundColor: "#ffd700",
        accentColor: "#daa520",
        fontName: "serif",
        borderStyle: "shadow",
        badgeIcon: "crown.fill",
        tagShape: "pill"
    )

    static let astro = WidgetSkin(
        id: "astro",
        name: "孙尚香",
        price: 100,
        description: "千金重弩，势如破竹",
        backgroundColor: "#0b0b1a",
        foregroundColor: "#ffffff",
        accentColor: "#ff7b8a",
        fontName: "rounded",
        borderStyle: "shadow",
        badgeIcon: "star.fill",
        tagShape: "pill",
        imageName: "widget_astro.png"
    )
}

/// Color from hex string helper
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xff, (int >> 8) & 0xff, int & 0xff)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xff, (int >> 16) & 0xff, (int >> 8) & 0xff, int & 0xff)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
