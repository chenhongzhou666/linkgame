import SwiftUI

struct GameHubView: View {
    @EnvironmentObject var auth: AuthState
    @Environment(\.dismiss) private var dismiss
    let onSelectMode: (GameMode) -> Void
    @State private var showLeaderboardFor: String? = nil
    @State private var showHistoryFor: String? = nil
    @State private var showUnlockAlert = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("泓泓看 · 玩法中心")
                    .font(.title2.bold())
                Spacer()
                Button("关闭") { dismiss() }
                    .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            HStack(spacing: 16) {
                ModeCard(mode: .daily,
                    isLocked: !(auth.currentUser?.isDailyUnlocked ?? false),
                    coins: auth.currentUser?.coins ?? 0,
                    onStart: { select(.daily) },
                    onLeaderboard: { showLeaderboardFor = dailyLeaderID() },
                    onHistory: { showHistoryFor = dailyLeaderID() },
                    onUnlock: { showUnlockAlert = true })
                ModeCard(mode: .timed,
                    onStart: { select(.timed) },
                    onLeaderboard: { showLeaderboardFor = "timed" },
                    onHistory: { showHistoryFor = "timed" })
            }
            .padding(20)

            Spacer()
        }
        .frame(minWidth: 480, minHeight: 320)
        .sheet(item: $showLeaderboardFor) { levelID in
            LeaderboardView(levelID: levelID)
        }
        .sheet(item: $showHistoryFor) { levelID in
            HistoryView(levelID: levelID)
        }
        .alert("解锁每日挑战", isPresented: $showUnlockAlert) {
            Button("取消", role: .cancel) { }
            Button("确认支付 5000 金币") { purchaseDaily() }
        } message: {
            Text("花费 5000 金币解锁每日挑战模式\n当前金币：\(auth.currentUser?.coins ?? 0)")
        }
    }

    private func select(_ mode: GameMode) {
        dismiss()
        onSelectMode(mode)
    }

    private func dailyLeaderID() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return "daily-\(df.string(from: Date()))"
    }

    private func purchaseDaily() {
        APIClient.token = auth.token
        Task {
            do {
                let resp = try await APIClient.unlockDaily()
                if let currency = resp.currency, var user = auth.currentUser {
                    user = User(id: user.id, username: user.username, nickname: user.nickname, email: user.email, avatar: user.avatar, currency: currency, dailyUnlocked: true, createdAt: user.createdAt)
                    auth.currentUser = user
                }
            } catch {
                print("解锁失败: \(error.localizedDescription)")
            }
        }
    }
}

struct ModeCard: View {
    let mode: GameMode
    var isLocked: Bool = false
    var coins: Int64 = 0
    let onStart: () -> Void
    let onLeaderboard: () -> Void
    let onHistory: () -> Void
    var onUnlock: (() -> Void)? = nil
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: isLocked ? "lock.fill" : mode.iconName)
                .font(.system(size: 32))
                .foregroundStyle(isLocked ? .gray : mode.accentColor)
                .padding(.top, 6)

            Text(mode.displayName)
                .font(.title3.bold())

            if isLocked {
                Text("需要 5000 金币解锁")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Text(mode.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if isLocked {
                Button(action: { onUnlock?() }) {
                    Label("5000 解锁", systemImage: "lock.open")
                        .font(.caption)
                        .frame(width: 120)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.small)
                .disabled(coins < 5000)
                .padding(.bottom, 8)
            } else {
                HStack(spacing: 6) {
                    Button(action: onHistory) {
                        Text("战绩").font(.caption).frame(width: 52)
                    }
                    .buttonStyle(.bordered).controlSize(.small)

                    Button(action: onLeaderboard) {
                        Text("排行").font(.caption).frame(width: 52)
                    }
                    .buttonStyle(.bordered).controlSize(.small)

                    Button(action: onStart) {
                        Text("开始").font(.caption).frame(width: 52)
                    }
                    .buttonStyle(.borderedProminent).tint(mode.accentColor).controlSize(.small)
                }
                .padding(.bottom, 8)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.controlBackgroundColor).opacity(isHovered ? 0.8 : 0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isLocked ? Color.orange.opacity(0.3) : mode.accentColor.opacity(isHovered ? 0.5 : 0.2), lineWidth: 1.5)
        )
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

extension String: @retroactive Identifiable {
    public var id: String { self }
}
