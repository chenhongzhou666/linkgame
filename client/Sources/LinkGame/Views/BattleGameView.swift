import SwiftUI

struct BattleGameView: View {
    @StateObject private var wsClient = BattleWSClient()
    @StateObject private var game: BattleGameState
    @EnvironmentObject var auth: AuthState
    @Environment(\.dismiss) private var dismiss
    @State private var hoveredPoint: Point?
    @State private var shakeOffset: CGFloat = 0
    @State private var showResult = false
    @State private var didConnect = false
    private let theme = ThemeManager.shared.gameTheme

    init() {
        let client = BattleWSClient()
        _wsClient = StateObject(wrappedValue: client)
        _game = StateObject(wrappedValue: BattleGameState(wsClient: client))
    }

    var body: some View {
        ZStack {
            PixelArtBackground().opacity(0.3)

            VStack(spacing: 0) {
                headerBar
                Divider()

                if game.isPlaying || game.isFinished {
                    // 对战或结算后
                    battleView
                } else {
                    // 默认：在线玩家列表
                    playerListView
                }
            }
            .onChange(of: wsClient.state.label) { _ in game.syncWithWS() }
            .onChange(of: wsClient.lastHit?.myHP) { _ in
                if wsClient.lastHit != nil { game.syncWithWS() }
            }
            .onChange(of: game.burstPoint) { bp in
                if bp != nil { triggerShake() }
            }
            .onChange(of: game.isFinished) { finished in
                if finished { showResult = true }
            }
            .onAppear {
                if !didConnect {
                    didConnect = true
                    connect()
                }
            }
            .onDisappear { wsClient.disconnect() }

            // 邀请弹窗
            if let invite = wsClient.inviteReceived {
                inviteAlert(invite)
            }

            // 被踢弹窗
            if case .kicked(let msg) = wsClient.state {
                kickedOverlay(msg)
            }

            // 结算弹窗
            if showResult, let result = game.result {
                resultOverlay(result)
            }
        }
        .frame(minWidth: 620, minHeight: 720)
    }

    // MARK: - Connect

    private func connect() {
        guard let token = auth.token else {
            // token 还没好，重试
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { connect() }
            return
        }
        wsClient.connect(token: token)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Button { wsClient.disconnect(); dismiss() }
                label: { Label("返回", systemImage: "chevron.left") }
                .buttonStyle(.borderless).clickable()

            Text("⚔️ 双人对战")
                .font(.title2.bold())

            Spacer()
            WallpaperButton()
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
    }

    // MARK: - Player List (AirDrop 风格)

    private var playerListView: some View {
        let myId = auth.currentUser?.id ?? 0
        let others = wsClient.players.filter { $0.userId != myId }

        return VStack(spacing: 0) {
            // 调试信息
            if !wsClient.debugInfo.isEmpty {
                Text(wsClient.debugInfo)
                    .font(.caption).foregroundStyle(.blue)
                    .padding(.horizontal, 20).padding(.vertical, 2)
            }

            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(.blue)
                Text("轻点邀请附近的玩家对战").font(.subheadline)
                Spacer()
            }
            .padding(.horizontal, 20).padding(.vertical, 10)

            Divider()

            if others.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 56)).foregroundStyle(.secondary)
                    Text("暂无线上的玩家").font(.title3).foregroundStyle(.secondary)
                    Text("等另一个玩家进入即可看到").font(.caption).foregroundStyle(.secondary)
                    ProgressView().scaleEffect(0.6).padding(.top, 8)
                }
                Spacer()
            } else {
                inviteMessages()

                List(others) { player in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(.secondary.opacity(0.3))
                            .frame(width: 40, height: 40)
                            .overlay(Text(String(player.username.prefix(1))).font(.headline))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(player.username).font(.headline)
                            HStack(spacing: 4) {
                                Image(systemName: "trophy.fill").font(.caption2).foregroundStyle(.orange)
                                Text("\(player.trophies)").font(.caption).foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Button("邀请") {
                            wsClient.sendInvite(to: player.userId)
                        }
                        .buttonStyle(.borderedProminent).controlSize(.small)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }

            Spacer()

            HStack {
                Circle().fill(.green).frame(width: 8, height: 8)
                Text("\(others.count) 位玩家在线").font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20).padding(.bottom, 12)
        }
    }

    private func inviteMessages() -> some View {
        VStack(spacing: 0) {
            if let err = wsClient.inviteError {
                HStack {
                    Label(err, systemImage: "xmark.circle.fill").foregroundStyle(.red).font(.caption)
                    Spacer()
                    Button("知道了") { wsClient.inviteError = nil }.buttonStyle(.plain).font(.caption)
                }
                .padding(.horizontal, 20).padding(.vertical, 6).background(Color.red.opacity(0.1))
            }
            if let name = wsClient.inviteDeclinedBy {
                HStack {
                    Label("\(name) 拒绝了你的邀请", systemImage: "xmark.circle").foregroundStyle(.secondary).font(.caption)
                    Spacer()
                    Button("知道了") { wsClient.inviteDeclinedBy = nil }.buttonStyle(.plain).font(.caption)
                }
                .padding(.horizontal, 20).padding(.vertical, 6).background(Color.secondary.opacity(0.1))
            }
        }
    }

    // MARK: - Invite Alert

    private func inviteAlert(_ invite: InviteReceived) -> some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 48)).foregroundStyle(.blue)
                Text("\(invite.fromUsername)").font(.title2.bold()) + Text(" 邀请你对战")
                HStack(spacing: 4) {
                    Image(systemName: "trophy.fill").foregroundStyle(.orange)
                    Text("\(invite.fromTrophies) 个奖杯").font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 20) {
                    Button {
                        wsClient.respondToInvite(accept: false)
                    } label: {
                        Label("拒绝", systemImage: "xmark").frame(width: 100)
                    }.buttonStyle(.bordered).tint(.red)
                    Button {
                        wsClient.respondToInvite(accept: true)
                    } label: {
                        Label("接受", systemImage: "checkmark").frame(width: 100)
                    }.buttonStyle(.borderedProminent).tint(.green)
                }
            }
            .padding(32)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color(.windowBackgroundColor)))
            .shadow(radius: 20)
        }
    }

    // MARK: - Kicked

    private func kickedOverlay(_ message: String) -> some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48)).foregroundStyle(.orange)
                Text(message).font(.headline).multilineTextAlignment(.center)
                Button("确定") { wsClient.disconnect(); dismiss() }.buttonStyle(.borderedProminent)
            }
            .padding(32)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color(.windowBackgroundColor)))
            .shadow(radius: 20)
        }
    }

    // MARK: - Battle

    private var battleView: some View {
        VStack(spacing: 0) {
            StickFigureArena(
                myName: auth.currentUser?.displayName ?? "我",
                opponentName: game.opponentName,
                myHP: game.myHP,
                opponentHP: game.opponentHP,
                maxHP: game.maxHP,
                isShooting: game.isShooting,
                isTakingHit: game.isTakingHit
            ).padding(.vertical, 8)

            Divider()
            boardArea.padding(12)
            Divider()

            HStack {
                Text("消除配对，攻击对手！").font(.caption).foregroundStyle(.secondary)
            }.padding(.vertical, 6)
        }
    }

    // MARK: - Board

    private var boardArea: some View {
        GeometryReader { geo in
            let cols = game.board.cols
            let rows = game.board.rows
            let cellW = geo.size.width / CGFloat(cols)
            let cellH = geo.size.height / CGFloat(rows)
            let cellSize = min(cellW, cellH)

            VStack(spacing: 0) {
                ForEach(0..<rows, id: \.self) { r in
                    HStack(spacing: 0) {
                        ForEach(0..<cols, id: \.self) { c in
                            let point = Point(row: r, col: c)
                            let isEmpty = game.board.engine.isEmpty(at: point)
                            let isSelected = game.selectedTile == point
                            let isDisappearing = game.disappearingTiles.contains(point)
                            let isHovered = hoveredPoint == point && !isEmpty && !isDisappearing

                            ZStack {
                                if !isEmpty {
                                    Text(game.board.emoji(for: game.board.engine.getType(at: point)))
                                        .font(.system(size: cellSize * 0.48))
                                }
                            }
                            .frame(width: cellSize, height: cellSize)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(isEmpty ? Color.clear : theme.tileFill)
                                    .stroke(
                                        isSelected ? Color.blue : (isHovered ? theme.hoverBorder : theme.tileBorder),
                                        lineWidth: isSelected ? 3 : (isHovered ? 2.5 : 1)
                                    )
                            )
                            .scaleEffect(isDisappearing ? 1.4 : (isHovered ? 1.08 : 1.0))
                            .opacity(isDisappearing ? 0 : 1)
                            .animation(isDisappearing ? .spring(response: 0.3, dampingFraction: 0.5) : nil, value: isDisappearing)
                            .animation(.easeOut(duration: 0.12), value: isHovered)
                            .onHover { hovering in hoveredPoint = hovering ? point : nil }
                            .onTapGesture { game.tapTile(at: point) }
                        }
                    }
                }
            }
            .overlay {
                if let path = game.matchPath, path.count >= 2 {
                    Path { p in
                        let half = cellSize / 2
                        p.move(to: CGPoint(x: CGFloat(path[0].col) * cellSize + half, y: CGFloat(path[0].row) * cellSize + half))
                        for i in 1..<path.count {
                            p.addLine(to: CGPoint(x: CGFloat(path[i].col) * cellSize + half, y: CGFloat(path[i].row) * cellSize + half))
                        }
                    }
                    .stroke(theme.matchLine, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    .shadow(color: theme.matchLineGlow, radius: 6)
                }
                if let bp = game.burstPoint {
                    let cx = CGFloat(bp.col) * cellSize + cellSize / 2
                    let cy = CGFloat(bp.row) * cellSize + cellSize / 2
                    ShockwaveView(center: CGPoint(x: cx, y: cy))
                }
            }
        }
        .offset(y: shakeOffset)
    }

    // MARK: - Result

    private func resultOverlay(_ result: BattleGameState.BattleResult) -> some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 24) {
                switch result.outcome {
                case "win":
                    Text("🏆").font(.system(size: 64))
                    Text("你赢了！").font(.title.bold()).foregroundStyle(.green)
                    if result.trophies > 0 {
                        Text("+1 🏆  (共 \(result.trophies) 个)").font(.title3).foregroundStyle(.yellow)
                    }
                case "draw":
                    Text("🤝").font(.system(size: 64))
                    Text("平局！").font(.title.bold())
                default:
                    Text("😢").font(.system(size: 64))
                    Text("你输了").font(.title.bold()).foregroundStyle(.red)
                }

                HStack(spacing: 40) {
                    VStack(spacing: 4) {
                        Text(auth.currentUser?.displayName ?? "我").font(.subheadline).foregroundStyle(.secondary)
                        Text("\(result.myHP) HP").font(.title.bold()).foregroundStyle(.blue)
                    }
                    Text("vs").font(.title3).foregroundStyle(.secondary)
                    VStack(spacing: 4) {
                        Text(game.opponentName).font(.subheadline).foregroundStyle(.secondary)
                        Text("\(result.opponentHP) HP").font(.title.bold()).foregroundStyle(.red)
                    }
                }
                .padding(.vertical, 12).padding(.horizontal, 32)
                .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.08)))

                HStack(spacing: 16) {
                    Button {
                        showResult = false; game.isFinished = false; game.result = nil
                        wsClient.disconnect()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { connect() }
                    } label: {
                        Label("再来一局", systemImage: "arrow.counterclockwise").frame(width: 120)
                    }.buttonStyle(.borderedProminent)
                    Button {
                        wsClient.disconnect(); dismiss()
                    } label: {
                        Label("返回主菜单", systemImage: "house").frame(width: 120)
                    }.buttonStyle(.bordered)
                }
            }
            .padding(40)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color(.windowBackgroundColor).opacity(0.95)))
            .shadow(radius: 20)
        }
    }

    private func triggerShake() {
        withAnimation(.spring(response: 0.08, dampingFraction: 0.3)) { shakeOffset = -4 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            withAnimation(.spring(response: 0.08, dampingFraction: 0.3)) { shakeOffset = 3 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.1, dampingFraction: 0.4)) { shakeOffset = 0 }
        }
    }
}
