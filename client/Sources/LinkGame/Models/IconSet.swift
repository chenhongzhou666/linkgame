import Foundation

struct IconSet {
    let name: String
    let icons: [String]

    static let count = 20

    func icon(for type: Int) -> String {
        guard type > 0 && type <= icons.count else { return "❓" }
        return icons[type - 1]
    }

    static let defaultFruit = IconSet(
        name: "水果动物",
        icons: [
            "🍎", "🍊", "🍋", "🍇", "🍓", "🍒", "🥝", "🍑",
            "🌸", "🌻", "🍀", "🌙", "⭐", "🔥", "💧", "🎵",
            "🐶", "🐱", "🐰", "🦊"
        ]
    )

    static let animals = IconSet(
        name: "可爱动物",
        icons: [
            "🐶", "🐱", "🐰", "🦊", "🐻", "🐼", "🐨", "🐯",
            "🦁", "🐮", "🐷", "🐸", "🐵", "🐔", "🐧", "🐦",
            "🐤", "🦄", "🐙", "🦋"
        ]
    )

    static let space = IconSet(
        name: "星球宇宙",
        icons: [
            "🪐", "🌍", "☀️", "🌑", "💫", "⭐", "🌟", "🌙",
            "🔥", "💧", "🌈", "❄️", "⚡", "🌊", "🌋", "🎆",
            "🌎", "🌕", "🌗", "🌘"
        ]
    )
}
