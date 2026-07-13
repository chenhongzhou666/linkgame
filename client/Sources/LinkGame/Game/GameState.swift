import Foundation

@MainActor
class GameState: ObservableObject {
    @Published var board: Board
    @Published var selectedTile: Point?
    @Published var score: Int = 0
    @Published var combo: Int = 0
    @Published var timeElapsed: Int = 0
    @Published var isGameOver: Bool = false
    @Published var isVictory: Bool = false
    @Published var highlightPair: (Point, Point)?
    @Published var matchPath: [Point]?
    @Published var disappearingTiles: Set<Point> = []
    @Published var burstPoint: Point?
    @Published var isLoadingDaily = false
    @Published var remainingTime: Int = 120
    @Published var remainingSteps: Int = 60

    let mode: GameMode
    var isDaily: Bool { mode.isDaily }
    var levelID: String = "default"
    private var timer: Timer?

    init(innerRows: Int = 6, innerCols: Int = 10, mode: GameMode = .classic) {
        self.mode = mode
        self.board = Board(innerRows: innerRows, innerCols: innerCols)
        self.board.iconSet = ThemeManager.shared.iconSet
        newGame()
    }

    func newGame() {
        selectedTile = nil
        score = 0
        combo = 0
        timeElapsed = 0
        isGameOver = false
        isVictory = false
        highlightPair = nil
        matchPath = nil
        disappearingTiles = []
        burstPoint = nil
        remainingTime = mode.timeLimit
        remainingSteps = mode.stepLimit

        if isDaily {
            loadDailyLevel()
        } else {
            let layout = board.generateSolvableLayout()
            board.engine.loadLayout(layout)
            levelID = mode.rawValue
            startTimer()
        }
    }

    private func loadDailyLevel() {
        isLoadingDaily = true
        Task {
            do {
                let resp: DailyLevelResponse = try await APIClient.getDailyLevel()
                if let data = resp.layoutData.data(using: .utf8),
                   let layout = try? JSONDecoder().decode([[Int]].self, from: data) {
                    await MainActor.run {
                        board.engine.loadLayout(layout)
                        levelID = "daily-\(resp.date)"
                        isLoadingDaily = false
                        startTimer()
                    }
                } else {
                    await MainActor.run { fallbackToLocal() }
                }
            } catch {
                await MainActor.run { fallbackToLocal() }
            }
        }
    }

    private func fallbackToLocal() {
        let layout = board.generateSolvableLayout()
        board.engine.loadLayout(layout)
        levelID = mode.rawValue
        isLoadingDaily = false
        startTimer()
    }

    func loadLayout(_ layoutData: [[Int]]) {
        board.engine.loadLayout(layoutData)
        selectedTile = nil
        score = 0
        combo = 0
        timeElapsed = 0
        isGameOver = false
        isVictory = false
        highlightPair = nil
        startTimer()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, !self.isGameOver, !self.isVictory else { return }
                if self.mode.isTimed {
                    self.remainingTime -= 1
                    if self.remainingTime <= 0 {
                        self.remainingTime = 0
                        self.isGameOver = true
                        self.timer?.invalidate()
                    }
                } else {
                    self.timeElapsed += 1
                }
            }
        }
    }

    func tapTile(at point: Point) {
        guard !isGameOver && !isVictory else { return }
        guard !board.engine.isEmpty(at: point) else { return }

        if let first = selectedTile {
            if first == point {
                selectedTile = nil
                return
            }

            if let path = board.engine.findPath(first, point) {
                matchPath = path
                combo += 1
                score += 100 * combo

                if mode.isStepLimited {
                    remainingSteps -= 1
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                    guard let self = self else { return }
                    self.matchPath = nil
                    self.disappearingTiles = [first, point]
                    self.burstPoint = Point(
                        row: (first.row + point.row) / 2,
                        col: (first.col + point.col) / 2
                    )

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                        guard let self = self else { return }
                        self.board.engine.setEmpty(at: first)
                        self.board.engine.setEmpty(at: point)
                        self.disappearingTiles = []
                        self.burstPoint = nil

                        if self.board.engine.remainingTiles() == 0 {
                            switch self.mode {
                            case .classic, .daily:
                                self.score += self.timeElapsed * 10
                            case .timed:
                                self.score += self.remainingTime * 20
                            case .stepLimited:
                                self.score += self.remainingSteps * 15
                            }
                            self.isVictory = true
                            self.timer?.invalidate()
                        } else if self.mode.isStepLimited && self.remainingSteps <= 0 {
                            self.isGameOver = true
                            self.timer?.invalidate()
                        } else if self.board.engine.findAnyMatch() == nil {
                            self.isGameOver = true
                            self.timer?.invalidate()
                        }
                    }
                }
            } else {
                combo = 0
            }
            selectedTile = nil
        } else {
            selectedTile = point
        }
    }

    func shuffle() {
        let remaining = remainingPoints()
        var types = remaining.map { board.engine.getType(at: $0) }
        types.shuffle()

        var newGrid = Array(
            repeating: Array(repeating: 0, count: board.cols),
            count: board.rows
        )

        for i in 0..<remaining.count {
            newGrid[remaining[i].row][remaining[i].col] = types[i]
        }

        board.engine.loadLayout(newGrid)
        selectedTile = nil
        combo = 0
        score = max(0, score - 200)

        if board.engine.findAnyMatch() == nil {
            _ = resetUntilSolvable()
        }
    }

    func showHint() {
        if let pair = board.engine.findAnyMatch() {
            highlightPair = pair
            score = max(0, score - 300)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.highlightPair = nil
            }
        }
    }

    func remainingPoints() -> [Point] {
        var pts: [Point] = []
        for r in 0..<board.rows {
            for c in 0..<board.cols {
                let p = Point(row: r, col: c)
                if !board.engine.isEmpty(at: p) {
                    pts.append(p)
                }
            }
        }
        return pts
    }

    private func resetUntilSolvable() -> Bool {
        for _ in 0..<50 {
            let types = remainingPoints().map { board.engine.getType(at: $0) }
            var shuffled = types
            shuffled.shuffle()

            var newGrid = Array(
                repeating: Array(repeating: 0, count: board.cols),
                count: board.rows
            )
            let pts = remainingPoints()
            for i in 0..<pts.count {
                newGrid[pts[i].row][pts[i].col] = shuffled[i]
            }
            board.engine.loadLayout(newGrid)
            if board.engine.findAnyMatch() != nil {
                return true
            }
        }
        return false
    }

    deinit {
        timer?.invalidate()
    }
}
