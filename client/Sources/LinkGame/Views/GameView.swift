import SwiftUI

struct GameView: View {
    @StateObject private var game: GameState
    @EnvironmentObject var auth: AuthState
    @Environment(\.dismiss) private var dismiss
    @State private var showLeaderboard = false
    @State private var hoveredPoint: Point?
    @State private var shakeOffset: CGFloat = 0
    private let theme = ThemeManager.shared.gameTheme

    init(mode: GameMode = .classic) {
        _game = StateObject(wrappedValue: GameState(innerRows: 6, innerCols: 10, mode: mode))
    }

    var body: some View {
        ZStack {
            PixelArtBackground().opacity(0.3)

            VStack(spacing: 0) {
                headerBar
                Divider()
                boardArea
                    .padding(12)
                Divider()
                bottomBar
            }

            if game.isVictory || game.isGameOver {
                resultOverlay
            }
        }
        .sheet(isPresented: $showLeaderboard) {
            LeaderboardView(levelID: game.levelID)
        }
        .onChange(of: game.isVictory) { victory in
            if victory { submitScore() }
        }
        .onChange(of: game.isGameOver) { over in
            if over { submitScore() }
        }
        .frame(minWidth: 600, minHeight: 520)
    }

    private var headerBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Label("返回", systemImage: "chevron.left")
            }
            .buttonStyle(.borderless)
            .clickable()

            Text(game.mode.displayName)
                .font(.title2.bold())

            Spacer()

            Label("\(game.score)", systemImage: "star.fill")
                .foregroundStyle(.yellow)
            Text("·")
            if game.mode.isTimed {
                Label("\(timeString(game.remainingTime))", systemImage: "timer")
                    .foregroundStyle(game.remainingTime <= 30 ? .red : .secondary)
            } else if game.mode.isStepLimited {
                Label("\(game.remainingSteps)/\(game.mode.stepLimit) 步", systemImage: "shoeprints.fill")
                    .foregroundStyle(game.remainingSteps <= 10 ? .red : .secondary)
            } else {
                Label("\(timeString(game.timeElapsed))", systemImage: "clock")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            WallpaperButton()
                .padding(.horizontal, 4)

            Button("排行榜") { showLeaderboard = true }
                .buttonStyle(.bordered)
                .clickable()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var boardArea: some View {
        GeometryReader { geo in
            let innerRows = game.board.rows - 2
            let innerCols = game.board.cols - 2
            let cellW = geo.size.width / CGFloat(innerCols + 2)
            let cellH = geo.size.height / CGFloat(innerRows + 2)
            let cellSize = min(cellW, cellH)

            VStack(spacing: 0) {
                ForEach(0..<game.board.rows, id: \.self) { r in
                    HStack(spacing: 0) {
                        ForEach(0..<game.board.cols, id: \.self) { c in
                            let point = Point(row: r, col: c)
                            let isEmpty = game.board.engine.isEmpty(at: point)
                            let isSelected = game.selectedTile == point
                            let isHighlighted = game.highlightPair?.0 == point || game.highlightPair?.1 == point
                            let isDisappearing = game.disappearingTiles.contains(point)
                            let isHovered = hoveredPoint == point && !isEmpty && !isDisappearing

                            ZStack {
                                if !isEmpty {
                                    let type = game.board.engine.getType(at: point)
                                    Text(game.board.emoji(for: type))
                                        .font(.system(size: cellSize * 0.55))
                                }
                            }
                            .frame(width: cellSize, height: cellSize)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(isEmpty ? Color.clear : theme.tileFill)
                                    .stroke(
                                        isHighlighted ? theme.highlightBorder :
                                        (isSelected ? theme.selectedBorder :
                                        (isHovered ? theme.hoverBorder : theme.tileBorder)),
                                        lineWidth: isHighlighted ? 3 :
                                                   (isSelected ? 3 :
                                                   (isHovered ? 2.5 : 1))
                                    )
                            )
                            .scaleEffect(isDisappearing ? 1.4 : (isHovered ? 1.08 : 1.0))
                            .opacity(isDisappearing ? 0 : 1)
                            .animation(isDisappearing ? .spring(response: 0.3, dampingFraction: 0.5) : nil, value: isDisappearing)
                            .animation(.easeOut(duration: 0.12), value: isHovered)
                            .onHover { hovering in
                                hoveredPoint = hovering ? point : nil
                            }
                            .onTapGesture {
                                game.tapTile(at: point)
                            }
                        }
                    }
                }
            }
            .overlay {
                if let path = game.matchPath, path.count >= 2 {
                    Path { p in
                        let offset = cellSize / 2
                        p.move(to: CGPoint(
                            x: CGFloat(path[0].col) * cellSize + offset,
                            y: CGFloat(path[0].row) * cellSize + offset
                        ))
                        for i in 1..<path.count {
                            p.addLine(to: CGPoint(
                                x: CGFloat(path[i].col) * cellSize + offset,
                                y: CGFloat(path[i].row) * cellSize + offset
                            ))
                        }
                    }
                    .stroke(
                        theme.matchLine,
                        style: SwiftUI.StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: theme.matchLineGlow, radius: 6)
                    .shadow(color: theme.matchLine, radius: 12)
                    .animation(.none, value: game.matchPath)
                }

                // 冲击波
                if let bp = game.burstPoint {
                    let cx = CGFloat(bp.col) * cellSize + cellSize / 2
                    let cy = CGFloat(bp.row) * cellSize + cellSize / 2
                    ShockwaveView(center: CGPoint(x: cx, y: cy))
                }
            }
            .offset(y: shakeOffset)
            .onChange(of: game.burstPoint) { bp in
                if bp != nil { triggerShake() }
            }
        }
    }

    private func triggerShake() {
        withAnimation(.spring(response: 0.08, dampingFraction: 0.3)) {
            shakeOffset = -4
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            withAnimation(.spring(response: 0.08, dampingFraction: 0.3)) {
                shakeOffset = 3
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.1, dampingFraction: 0.4)) {
                shakeOffset = 0
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 24) {
            Button(action: { game.shuffle() }) {
                Label("洗牌 (-200)", systemImage: "shuffle")
            }
            .disabled(game.isVictory || game.isGameOver)

            Button(action: { game.showHint() }) {
                Label("提示 (-300)", systemImage: "lightbulb")
            }
            .disabled(game.isVictory || game.isGameOver)

            Spacer()

            Button("新游戏") { game.newGame() }
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var resultOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text(game.isVictory ? "🎉" : "😅")
                    .font(.system(size: 64))

                Text(game.isVictory ? "恭喜通关！" : gameOverMessage)
                    .font(.title.bold())
                    .foregroundStyle(.white)

                VStack(spacing: 8) {
                    Text("得分：\(game.score)")
                        .font(.title2)
                        .foregroundStyle(.yellow)
                    if game.mode.isTimed {
                        Text("用时：\(timeString(game.mode.timeLimit - game.remainingTime))")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.8))
                    } else {
                        Text("用时：\(timeString(game.timeElapsed))")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    if game.isVictory {
                        Text(bonusText)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                HStack(spacing: 16) {
                    Button {
                        game.newGame()
                    } label: {
                        Label("再来一局", systemImage: "arrow.counterclockwise")
                            .frame(width: 120)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        dismiss()
                    } label: {
                        Label("返回主菜单", systemImage: "house")
                            .frame(width: 120)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.windowBackgroundColor).opacity(0.95))
            )
            .shadow(radius: 20)
        }
    }

    private var gameOverMessage: String {
        if game.mode.isTimed { return "时间到！" }
        if game.mode.isStepLimited { return "步数用完！" }
        return "没有可消除的了"
    }

    private var bonusText: String {
        switch game.mode {
        case .classic, .daily:
            return "时间加分：+\(game.timeElapsed * 10)"
        case .timed:
            return "剩余时间加分：+\(game.remainingTime * 20)"
        case .stepLimited:
            return "剩余步数加分：+\(game.remainingSteps * 15)"
        case .battle:
            return ""
        }
    }

    private func timeString(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func submitScore() {
        APIClient.token = auth.token
        Task {
            if let resp = try? await APIClient.submitScore(
                levelID: game.levelID,
                score: game.score,
                timeSeconds: game.timeElapsed
            ) {
                if let currency = resp.currency, var user = auth.currentUser {
                    user = User(id: user.id, username: user.username, nickname: user.nickname, email: user.email, avatar: user.avatar, currency: currency, dailyUnlocked: user.dailyUnlocked, trophies: user.trophies, createdAt: user.createdAt)
                    auth.currentUser = user
                }
            }
        }
    }
}

struct ShockwaveView: View {
    let center: CGPoint
    @State private var animating = false

    var body: some View {
        Circle()
            .stroke(Color.white.opacity(0.6), lineWidth: 3)
            .frame(width: animating ? 60 : 4, height: animating ? 60 : 4)
            .position(center)
            .opacity(animating ? 0 : 0.8)
            .animation(.easeOut(duration: 0.35), value: animating)
            .onAppear { animating = true }
    }
}
