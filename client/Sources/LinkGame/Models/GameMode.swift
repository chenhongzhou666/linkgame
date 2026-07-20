import SwiftUI

enum GameMode: String, CaseIterable, Identifiable {
    case classic
    case daily
    case timed
    case stepLimited
    case battle

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic:      return "经典模式"
        case .daily:        return "每日挑战"
        case .timed:        return "限时模式"
        case .stepLimited:  return "步步为营"
        case .battle:       return "双人对战"
        }
    }

    var description: String {
        switch self {
        case .classic:      return "不限时间与步数，自由享受消除的乐趣"
        case .daily:        return "每日统一关卡，与全球玩家比拼最高分"
        case .timed:        return "120秒倒计时，考验你的反应与手速"
        case .stepLimited:  return "仅60步可用，每一步都要深思熟虑"
        case .battle:       return "同屏双人轮流消除，比拼反应与眼力"
        }
    }

    var iconName: String {
        switch self {
        case .classic:      return "play.rectangle.fill"
        case .daily:        return "calendar.badge.clock"
        case .timed:        return "timer"
        case .stepLimited:  return "shoeprints.fill"
        case .battle:       return "person.2.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .classic:      return .blue
        case .daily:        return .orange
        case .timed:        return .red
        case .stepLimited:  return .purple
        case .battle:       return .green
        }
    }

    var isDaily: Bool { self == .daily }
    var isTimed: Bool { self == .timed }
    var isStepLimited: Bool { self == .stepLimited }
    var isBattle: Bool { self == .battle }
    var timeLimit: Int { 120 }
    var stepLimit: Int { 60 }
}
