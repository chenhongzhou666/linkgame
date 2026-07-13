import SwiftUI

enum Wallpaper: String, CaseIterable {
    case pixelArt = "像素风"
    case gradient = "渐变紫"

    var icon: String {
        switch self {
        case .pixelArt: return "circle.grid.3x3.fill"
        case .gradient: return "paintpalette.fill"
        }
    }
}

class WallpaperManager: ObservableObject {
    static let shared = WallpaperManager()

    @Published var current: Wallpaper {
        didSet { UserDefaults.standard.set(current.rawValue, forKey: "wallpaper") }
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: "wallpaper"),
           let wp = Wallpaper(rawValue: raw) {
            current = wp
        } else {
            current = .pixelArt
        }
    }

    func cycle() {
        let all = Wallpaper.allCases
        guard let idx = all.firstIndex(of: current) else { return }
        current = all[(idx + 1) % all.count]
    }
}
