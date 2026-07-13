# 003 · 啪嗒消失特效（含打击感）

**状态：** ✅ 已实现  
**日期：** 2026-07-12

## 效果

棋子匹配消除时三步连击：

1. 黄色连线闪现（002，0.25 秒）
2. 棋子放大 1.4 倍 + 淡出消失（弹簧 0.3 秒）
3. **打击感**：
   - 冲击波白圈从两点中心扩散消失（0.35 秒）
   - 棋盘轻微上下震动（0.12 秒回弹）

## 时序

```
匹配 → 连线(0.25s) → 爆开+震屏+冲击波(0.3s) → 棋子移除
```

## 实现位置

- **状态**：`GameState.swift` — `disappearingTiles` + `burstPoint`
- **棋子动画**：`GameView.swift` — `.scaleEffect(1.4)` + `.opacity(0)` + spring
- **冲击波**：`GameView.swift` — `ShockwaveView`（扩散白圈）
- **震屏**：`GameView.swift` — `triggerShake()`（y 轴弹簧偏移）
