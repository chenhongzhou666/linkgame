import SwiftUI

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @AppStorage("current_theme") var currentTheme: String = "default"

    var gameTheme: GameTheme {
        switch currentTheme {
        case "dark": return .dark
        default:     return .default
        }
    }

    var iconSet: IconSet {
        switch currentTheme {
        case "dark": return .space
        default:     return .defaultFruit
        }
    }

    var themeName: String {
        switch currentTheme {
        case "dark": return "暗黑霓虹"
        default:     return "默认蓝白"
        }
    }

    var availableThemes: [(id: String, name: String)] {
        [
            ("default", "默认蓝白"),
            ("dark", "暗黑霓虹")
        ]
    }
}
