# 002 · 连线消除特效

**状态：** ✅ 已实现  
**日期：** 2026-07-12

## 效果

两个棋子匹配消除时，先闪过黄色连线（0.25 秒），显示实际的连接路径后再消除棋子。

- 黄色主线 + 橙色发光外晕
- 路径为算法计算的最短转弯路径
- 折线节点处圆角过渡

## 实现位置

- **算法**：`client/Sources/LinkGame/Game/LinkEngine.swift` — `findPath()` + `reconstructPath()` + `simplifyPath()`
- **状态**：`client/Sources/LinkGame/Game/GameState.swift` — `matchPath` 属性，匹配后延迟 0.25s 消除
- **渲染**：`client/Sources/LinkGame/Views/GameView.swift` — `Path` overlay + 发光 shadow

## 关键代码

```swift
// 匹配成功后
if let path = board.engine.findPath(first, point) {
    matchPath = path  // 显示连线
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
        board.engine.setEmpty(at: first)
        board.engine.setEmpty(at: point)
        matchPath = nil  // 隐藏连线
    }
}

// 渲染
Path { p in
    p.move(to: cellCenter(path[0]))
    for i in 1..<path.count { p.addLine(to: cellCenter(path[i])) }
}
.stroke(Color.yellow, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
.shadow(color: .orange, radius: 6)
.shadow(color: .yellow, radius: 12)
```

## 路径简化

BFS 返回的逐格路径经过 `simplifyPath()` 精简，只保留起点、终点和转弯点，中间直线上格子不绘制。
