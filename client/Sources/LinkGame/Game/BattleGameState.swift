import Foundation

/// 在线对战状态管理 — WebSocket 驱动
@MainActor
class BattleGameState: ObservableObject {
    // MARK: - Published

    @Published var board: Board
    @Published var selectedTile: Point?
    @Published var myHP: Int = 100
    @Published var opponentHP: Int = 100
    @Published var maxHP: Int = 100
    @Published var opponentName: String = ""
    @Published var isPlaying: Bool = false
    @Published var isFinished: Bool = false
    @Published var result: BattleResult?

    // 特效
    @Published var matchPath: [Point]?
    @Published var disappearingTiles: Set<Point> = []
    @Published var burstPoint: Point?
    @Published var isShooting: Bool = false
    @Published var isTakingHit: Bool = false
    @Published var justScored: Bool = false

    // WS 客户端
    let wsClient: BattleWSClient
    private var isAnimating: Bool = false

    struct BattleResult {
        let outcome: String        // "win", "lose", "draw"
        let myHP: Int
        let opponentHP: Int
        let trophies: Int
    }

    // MARK: - Init

    init(wsClient: BattleWSClient) {
        self.wsClient = wsClient
        self.board = Board(innerRows: 10, innerCols: 10)
        self.board.iconSet = ThemeManager.shared.iconSet

        setupBindings()
    }

    private func setupBindings() {
        // 监听 WS 状态变化
        Task {
            for await _ in NotificationCenter.default.notifications(named: .battleStateChanged) {
                handleWSState()
            }
        }
    }

    /// 由 View 调用，在 WS 状态变化时同步本地状态
    func syncWithWS() {
        handleWSState()
    }

    private func handleWSState() {
        switch wsClient.state {
        case .playing(let info):
            opponentName = info.opponentName
            myHP = info.hp
            opponentHP = info.hp
            maxHP = info.hp
            board.engine.loadLayout(info.board)
            isPlaying = true
            isFinished = false
            result = nil
            selectedTile = nil
            isShooting = false
            isTakingHit = false

        case .finished(let info):
            isPlaying = false
            isFinished = true
            result = BattleResult(
                outcome: info.result,
                myHP: info.myHP,
                opponentHP: info.opponentHP,
                trophies: info.trophies
            )

        default:
            break
        }

        // 处理 hit 消息
        if let hit = wsClient.lastHit {
            if hit.attacker == "me" {
                // 我打了对手
                opponentHP = hit.opponentHP
                triggerShoot()
            } else {
                // 对手打了我
                myHP = hit.myHP
                triggerTakeHit()
            }
            wsClient.lastHit = nil
        }
    }

    // MARK: - Actions

    func tapTile(at point: Point) {
        guard isPlaying, !isFinished, !isAnimating else { return }
        guard !board.engine.isEmpty(at: point) else { return }

        if let first = selectedTile {
            if first == point {
                selectedTile = nil
                return
            }

            if let path = board.engine.findPath(first, point) {
                performMatch(first: first, second: point, path: path)
            } else {
                selectedTile = nil
            }
        } else {
            selectedTile = point
        }
    }

    private func performMatch(first: Point, second: Point, path: [Point]) {
        isAnimating = true
        selectedTile = nil
        matchPath = path

        // 发送到服务器
        wsClient.sendMatch(row1: first.row, col1: first.col, row2: second.row, col2: second.col)

        // 动画阶段 1 — 显示连线
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self = self else { return }
            self.matchPath = nil
            self.disappearingTiles = [first, second]
            self.burstPoint = Point(
                row: (first.row + second.row) / 2,
                col: (first.col + second.col) / 2
            )

            // 动画阶段 2 — 消除
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                self.board.engine.setEmpty(at: first)
                self.board.engine.setEmpty(at: second)
                self.disappearingTiles = []
                self.burstPoint = nil
                self.isAnimating = false

                // 检查棋盘清空
                if self.board.engine.remainingTiles() == 0 {
                    // 服务器会检测并下发 game_over
                }
            }
        }
    }

    // MARK: - 动画触发

    private func triggerShoot() {
        isShooting = true
        justScored = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isShooting = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.justScored = false
        }
    }

    private func triggerTakeHit() {
        isTakingHit = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isTakingHit = false
        }
    }

    // MARK: - Helpers

    func remainingTilesCount() -> Int {
        board.engine.remainingTiles()
    }
}

extension Notification.Name {
    static let battleStateChanged = Notification.Name("battleStateChanged")
}
