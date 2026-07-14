import SwiftUI
import UniformTypeIdentifiers

extension Notification.Name {
    static let avatarDropped = Notification.Name("avatarDropped")
}

struct ContentView: View {
    @EnvironmentObject var auth: AuthState
    @State private var showGame = false
    @State private var showGameHub = false
    @State private var selectedGameMode: GameMode?
    @State private var showLeaderboardFor: String? = nil
    @State private var showSettings = false
    @State private var refreshStats = 0
    @State private var isDropTargeted = false
    @State private var showCurrencyLogs = false
    @State private var showWidgetStore = false

    var body: some View {
        VStack(spacing: 0) {
            // 右上角：壁纸切换 + 金币
            if let user = auth.currentUser {
                HStack {
                    Spacer()
                    WallpaperButton()
                    Button(action: { showWidgetStore = true }) {
                        Image(systemName: "rectangle.3.group.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.ultraThinMaterial)
                    )
                    .help("桌面挂件商店")
                    Button(action: { WidgetWindowController.shared.show() }) {
                        Image(systemName: "macwindow.and.cursorarrow")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.ultraThinMaterial)
                    )
                    .help("显示浮动桌面挂件")
                    Button(action: { showCurrencyLogs = true }) {
                        Label("\(user.coins)", systemImage: "dollarsign.circle.fill")
                            .font(.title3.bold())
                            .foregroundStyle(.yellow)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.ultraThinMaterial)
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            VStack(spacing: 12) {
                if let user = auth.currentUser {
                    AvatarView(avatar: user.avatar, size: 64)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    isDropTargeted ? Color.blue : Color.clear,
                                    style: StrokeStyle(lineWidth: 3, dash: [6, 3])
                                )
                        )
                        .onDrop(of: [.png, .jpeg], isTargeted: $isDropTargeted) { providers in
                            handleDrop(providers: providers)
                        }
                        .help("拖拽图片到此处更换头像")

                    Text(user.displayName)
                        .font(.largeTitle.bold())
                    Text("@\(user.username)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    AppLogo(size: 72)
                    Text("泓泓看")
                        .font(.largeTitle.bold())
                }
            }
            .padding(.top, 60)

            Spacer().frame(height: 48)

            VStack(spacing: 12) {
                Button(action: { showGame = true }) {
                    Label("开始游戏", systemImage: "play.fill")
                        .frame(width: 180)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .clickable()

                Button(action: { showGameHub = true }) {
                    Label("玩法中心", systemImage: "square.grid.2x2.fill")
                        .frame(width: 180)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .clickable()
            }

            Spacer()

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: { showLeaderboardFor = "classic" }) {
                        Label("排行榜", systemImage: "trophy")
                    }
                    .buttonStyle(.borderless)
                    .clickable()

                    ThemePickerView()
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                InlineStatsView(refreshTrigger: refreshStats, levelID: "classic")
                    .frame(maxWidth: .infinity)

                VStack(alignment: .trailing, spacing: 8) {
                    Button(action: { showSettings = true }) {
                        Label("设置", systemImage: "gearshape")
                    }
                    .buttonStyle(.borderless)
                    .clickable()

                    Button(action: { auth.logout() }) {
                        Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .buttonStyle(.borderless)
                    .clickable()
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
        }
        .frame(minWidth: 480, minHeight: 500)
        .sheet(isPresented: $showGame) {
            GameView(mode: .classic).environmentObject(auth)
        }
        .sheet(isPresented: $showGameHub) {
            GameHubView(onSelectMode: { mode in
                showGameHub = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    selectedGameMode = mode
                }
            })
        }
        .sheet(item: $selectedGameMode) { mode in
            GameView(mode: mode).environmentObject(auth)
        }
        .sheet(item: $showLeaderboardFor) { levelID in
            LeaderboardView(levelID: levelID).frame(minWidth: 500, minHeight: 400)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(auth)
        }
        .sheet(isPresented: $showCurrencyLogs) {
            CurrencyLogView().environmentObject(auth)
        }
        .sheet(isPresented: $showWidgetStore) {
            WidgetStoreView().environmentObject(auth)
        }
        .onChange(of: showGame) { closed in
            if !closed { refreshStats += 1 }
        }
        .onChange(of: selectedGameMode) { _ in
            if selectedGameMode == nil { refreshStats += 1 }
        }
        .onReceive(NotificationCenter.default.publisher(for: .avatarDropped)) { notif in
            guard let url = notif.object as? URL else { return }
            doUpload(url: url)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        for type in [UTType.png, .jpeg] {
            if provider.hasItemConformingToTypeIdentifier(type.identifier) {
                provider.loadItem(forTypeIdentifier: type.identifier, options: nil) { item, _ in
                    guard let url = item as? URL else { return }
                    // 零捕获：只用 NotificationCenter 传出 URL
                    NotificationCenter.default.post(name: .avatarDropped, object: url)
                }
                return true
            }
        }
        return false
    }

    private func doUpload(url: URL) {
        let currentAuth = auth
        let username = currentAuth.currentUser?.username ?? ""
        let nick = currentAuth.currentUser?.nickname ?? ""
        let email = currentAuth.currentUser?.email
        let createdAt = currentAuth.currentUser?.createdAt
        let token = currentAuth.token ?? ""

        guard let data = try? Data(contentsOf: url) else { return }

        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "\(APIClient.baseURL)/api/me/avatar/upload")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"avatar.png\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { respData, _, error in
            guard error == nil, let respData = respData,
                  let json = try? JSONSerialization.jsonObject(with: respData) as? [String: String],
                  let newAvatar = json["avatar"] else { return }
            DispatchQueue.main.async {
                currentAuth.currentUser = User(id: currentAuth.currentUser?.id ?? 0, username: username, nickname: nick, email: email, avatar: newAvatar, currency: currentAuth.currentUser?.currency, dailyUnlocked: currentAuth.currentUser?.dailyUnlocked, createdAt: createdAt)
                AccountManager.shared.updateAccountInfo(username: username, avatar: newAvatar, nickname: nick)
            }
        }.resume()
    }
}

struct InlineStatsView: View {
    @EnvironmentObject var auth: AuthState
    @State private var stats: StatsResponse?
    @State private var showHistory = false
    let refreshTrigger: Int
    var levelID: String? = nil

    private var label: String {
        switch levelID {
        case "classic": return "经典战绩"
        case "timed":   return "限时战绩"
        case "step":    return "步步为营"
        default:        return "我的战绩"
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let s = stats {
                HStack(spacing: 20) {
                    StatItem(value: "\(s.totalGames)", label: "总局")
                    StatItem(value: "\(s.bestScore)", label: "最高分")
                    StatItem(value: String(format: "%.1fs", s.avgTime), label: "平均")
                }
                Button("查看记录") { showHistory = true }
                    .buttonStyle(.borderless)
                    .font(.caption2)
                    .clickable()
            } else {
                Text("加载中...")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: refreshTrigger) {
            APIClient.token = auth.token
            stats = try? await APIClient.getMyStats(levelID: levelID)
        }
        .sheet(isPresented: $showHistory) {
            HistoryView(levelID: levelID).environmentObject(auth)
        }
    }
}

struct StatItem: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 15, weight: .bold))
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }
}

struct CurrencyLogView: View {
    @EnvironmentObject var auth: AuthState
    @Environment(\.dismiss) private var dismiss
    @State private var logs: [CurrencyLog] = []
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("金币流水")
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
            } else if logs.isEmpty {
                Spacer()
                Text("暂无流水记录").foregroundStyle(.secondary)
                Spacer()
            } else {
                List(logs) { log in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(log.reason)
                                .font(.subheadline)
                            Text(formatDate(log.createdAt))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(log.amount > 0 ? "+\(log.amount)" : "\(log.amount)")
                            .fontWeight(.medium)
                            .foregroundStyle(log.amount > 0 ? .green : .red)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(minWidth: 380, minHeight: 400)
        .task { await load() }
    }

    private func load() async {
        APIClient.token = auth.token
        do {
            let resp = try await APIClient.getCurrencyLogs()
            logs = resp.logs ?? []
        } catch {
            print("流水加载失败: \(error)")
        }
        isLoading = false
    }

    private func formatDate(_ raw: String) -> String {
        let serverFmt = DateFormatter()
        serverFmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        serverFmt.timeZone = TimeZone(identifier: "Asia/Shanghai")
        if let date = serverFmt.date(from: raw) {
            let display = DateFormatter()
            display.dateFormat = "MM-dd HH:mm"
            return display.string(from: date)
        }
        return String(raw.prefix(16))
    }
}

struct ThemePickerView: View {
    @StateObject private var manager = ThemeManager.shared
    var body: some View {
        HStack(spacing: 4) {
            Label("主题", systemImage: "paintpalette")
            Picker("", selection: $manager.currentTheme) {
                ForEach(manager.availableThemes, id: \.id) { t in
                    Text(t.name).tag(t.id)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 90)
            .labelsHidden()
        }
    }
}
