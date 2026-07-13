import Foundation

struct Board {
    static let tileTypes = IconSet.count

    let rows: Int
    let cols: Int
    let engine: LinkEngine
    var iconSet: IconSet = .defaultFruit

    init(innerRows: Int, innerCols: Int) {
        self.rows = innerRows + 2
        self.cols = innerCols + 2
        self.engine = LinkEngine(rows: rows, cols: cols)
    }

    func emoji(for type: Int) -> String {
        return iconSet.icon(for: type)
    }

    func generateLayout() -> [[Int]] {
        let innerRows = rows - 2
        let innerCols = cols - 2
        let totalCells = innerRows * innerCols
        let pairs = totalCells / 2

        var tiles: [Int] = []
        for i in 0..<pairs {
            let type = (i % Self.tileTypes) + 1
            tiles.append(type)
            tiles.append(type)
        }
        tiles.shuffle()

        var layout = Array(
            repeating: Array(repeating: 0, count: cols),
            count: rows
        )

        var idx = 0
        for r in 1...innerRows {
            for c in 1...innerCols {
                layout[r][c] = tiles[idx]
                idx += 1
            }
        }

        return layout
    }

    func generateSolvableLayout() -> [[Int]] {
        for _ in 0..<100 {
            let layout = generateLayout()
            engine.loadLayout(layout)
            if engine.findAnyMatch() != nil {
                return layout
            }
        }
        return generateLayout()
    }
}
