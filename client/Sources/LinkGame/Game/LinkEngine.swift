import Foundation

struct Point: Hashable {
    let row: Int
    let col: Int
}

struct PathSegment: Hashable {
    let point: Point
    let direction: Int
    let turns: Int
}

private struct BFSNode {
    let seg: PathSegment
    let parentIndex: Int
}

class LinkEngine {
    private let rows: Int
    private let cols: Int
    private var grid: [[Int]]

    private let dr = [-1, 0, 1, 0]
    private let dc = [0, 1, 0, -1]

    init(rows: Int, cols: Int) {
        self.rows = rows
        self.cols = cols
        self.grid = []
    }

    func loadLayout(_ layout: [[Int]]) {
        grid = layout
    }

    func setEmpty(at p: Point) {
        guard p.row >= 0 && p.row < rows && p.col >= 0 && p.col < cols else { return }
        grid[p.row][p.col] = 0
    }

    func getType(at p: Point) -> Int {
        guard p.row >= 0 && p.row < rows && p.col >= 0 && p.col < cols else { return 0 }
        return grid[p.row][p.col]
    }

    func isEmpty(at p: Point) -> Bool {
        return getType(at: p) == 0
    }

    func isValid(_ p: Point) -> Bool {
        return p.row >= 0 && p.row < rows && p.col >= 0 && p.col < cols
    }

    func canConnect(_ a: Point, _ b: Point) -> Bool {
        return findPath(a, b) != nil
    }

    func findPath(_ a: Point, _ b: Point) -> [Point]? {
        if a == b { return nil }
        let typeA = getType(at: a)
        let typeB = getType(at: b)
        if typeA == 0 || typeB == 0 { return nil }
        if typeA != typeB { return nil }

        var queue: [BFSNode] = []
        var visited: Set<PathSegment> = []

        for dir in 0..<4 {
            let nr = a.row + dr[dir]
            let nc = a.col + dc[dir]
            let np = Point(row: nr, col: nc)

            if !isValid(np) { continue }
            if np == b { return [a, b] }

            if isEmpty(at: np) {
                let seg = PathSegment(point: np, direction: dir, turns: 0)
                if !visited.contains(seg) {
                    visited.insert(seg)
                    queue.append(BFSNode(seg: seg, parentIndex: -1))
                }
            }
        }

        var head = 0
        while head < queue.count {
            let cur = queue[head]

            for newDir in 0..<4 {
                let nr = cur.seg.point.row + dr[newDir]
                let nc = cur.seg.point.col + dc[newDir]
                let np = Point(row: nr, col: nc)

                if !isValid(np) { continue }

                let newTurns = cur.seg.turns + (newDir != cur.seg.direction ? 1 : 0)
                if newTurns > 2 { continue }

                if np == b {
                    return reconstructPath(queue: queue, endIndex: head, endPoint: b, startPoint: a)
                }

                if isEmpty(at: np) {
                    let next = PathSegment(point: np, direction: newDir, turns: newTurns)
                    if !visited.contains(next) {
                        visited.insert(next)
                        queue.append(BFSNode(seg: next, parentIndex: head))
                    }
                }
            }

            head += 1
        }

        return nil
    }

    private func reconstructPath(queue: [BFSNode], endIndex: Int, endPoint: Point, startPoint: Point) -> [Point] {
        var cells: [Point] = [endPoint]
        var idx = endIndex
        while idx >= 0 {
            cells.append(queue[idx].seg.point)
            idx = queue[idx].parentIndex
        }
        cells.append(startPoint)
        cells.reverse()
        return simplifyPath(cells)
    }

    private func simplifyPath(_ cells: [Point]) -> [Point] {
        if cells.count <= 2 { return cells }
        var result: [Point] = [cells[0]]
        for i in 1..<(cells.count - 1) {
            let dr1 = cells[i].row - cells[i-1].row
            let dc1 = cells[i].col - cells[i-1].col
            let dr2 = cells[i+1].row - cells[i].row
            let dc2 = cells[i+1].col - cells[i].col
            if dr1 != dr2 || dc1 != dc2 {
                result.append(cells[i])
            }
        }
        result.append(cells.last!)
        return result
    }

    func findAnyMatch() -> (Point, Point)? {
        var byType: [Int: [Point]] = [:]
        for r in 0..<rows {
            for c in 0..<cols {
                let t = grid[r][c]
                if t != 0 {
                    byType[t, default: []].append(Point(row: r, col: c))
                }
            }
        }

        for (_, tiles) in byType {
            for i in 0..<tiles.count {
                for j in (i + 1)..<tiles.count {
                    if canConnect(tiles[i], tiles[j]) {
                        return (tiles[i], tiles[j])
                    }
                }
            }
        }
        return nil
    }

    func remainingTiles() -> Int {
        var count = 0
        for r in 0..<rows {
            for c in 0..<cols {
                if grid[r][c] != 0 { count += 1 }
            }
        }
        return count
    }
}
