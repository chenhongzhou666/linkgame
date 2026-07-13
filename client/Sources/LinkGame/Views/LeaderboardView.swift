import SwiftUI

struct LeaderboardView: View {
    var levelID: String?
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [LeaderboardEntry] = []
    @State private var isLoading = true
    @State private var errorMsg: String?

    private var title: String {
        switch levelID {
        case "classic": return "经典模式 · 本周"
        case "timed":   return "限时模式 · 本周"
        case "step":    return "步步为营 · 本周"
        case let lid where lid?.hasPrefix("daily") == true: return "每日挑战"
        default:        return "本周排行榜"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.title2.bold())
                Spacer()
                Button("关闭") { dismiss() }
                    .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if let error = errorMsg {
                Spacer()
                Text(error).foregroundStyle(.secondary)
                Spacer()
            } else if entries.isEmpty {
                Spacer()
                Text("暂无记录").foregroundStyle(.secondary)
                Spacer()
            } else {
                List(entries) { entry in
                    HStack {
                        Text("#\(entry.rank)")
                            .font(.headline)
                            .foregroundStyle(rankColor(entry.rank))
                            .frame(width: 40, alignment: .leading)

                        if let avatar = entry.avatar, !avatar.isEmpty {
                            AvatarView(avatar: avatar, size: 26)
                        }

                        Text(entry.username)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("\(entry.score) 分")
                            .fontWeight(.medium)

                        Text(formatTime(entry.timeSeconds))
                            .foregroundStyle(.secondary)
                            .frame(width: 50, alignment: .trailing)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        do {
            let resp: LeaderboardResponse = try await APIClient.getLeaderboard(
                levelID: levelID,
                limit: 50
            )
            entries = resp.leaderboard
        } catch {
            errorMsg = error.localizedDescription
        }
        isLoading = false
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return .orange
        case 2: return .gray
        case 3: return .brown
        default: return .secondary
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
