# 001 · 白色描边悬停

**状态：** ✅ 已实现  
**日期：** 2026-07-12

## 效果

鼠标划过棋盘上的棋子时：
- 白色半透明描边（`Color.white.opacity(0.9)`）
- 棋子微放大 1.08 倍
- 0.12 秒 ease-out 过渡动画

## 实现位置

`client/Sources/LinkGame/Views/GameView.swift` — `boardArea` 的 tile 循环

## 关键代码

```swift
// hover 状态
@State private var hoveredPoint: Point?

// 描边逻辑（在 .stroke 中）
isHovered ? Color.white.opacity(0.9) : Color.blue.opacity(0.2)
isHovered ? 2.5 : 1

// 缩放 + 动画
.scaleEffect(isHovered ? 1.08 : 1.0)
.animation(.easeOut(duration: 0.12), value: isHovered)

// 监听鼠标
.onHover { hovering in
    hoveredPoint = hovering ? point : nil
}
```

## 描边优先级

1. 提示高亮（绿色）
2. 已选中（橙色）
3. **悬停描边（白色）** ← 本扩展
4. 默认（浅蓝细线）
