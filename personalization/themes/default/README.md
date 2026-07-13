# 默认主题

**状态：** ✅ 已实现  

## 包含内容

| 分类 | 编号 | 内容 | 说明 |
|------|------|------|------|
| 描边 | 001 | 白色描边悬停 | 鼠标划过 → 白边 + 微放大 |
| 描边 | 002 | 连线消除特效 | 匹配时黄色路径线 + 光晕 |
| 特效 | 003 | 啪嗒消失 | 棋子爆开 + 冲击波 + 棋盘震动 |
| 图标 | E01 | 水果动物 | 20 种 emoji |
| 配色 | — | 蓝白 | 蓝色半透明棋子 + 橙色选中 + 绿色提示 |

## 配色

| 元素 | 颜色 |
|------|------|
| 棋子填充 | `Color.blue.opacity(0.08)` |
| 默认边框 | `Color.blue.opacity(0.2)` |
| 悬停描边 | `Color.white.opacity(0.9)` |
| 选中描边 | `Color.orange` |
| 提示描边 | `Color.green.opacity(0.9)` |

## 代码

- `GameView.swift` — 描边、特效渲染
- `GameState.swift` — 特效状态
- `LinkEngine.swift` — 路径计算
- `Board.swift` → `IconSet.defaultFruit`
- `Theme.swift` → `GameTheme.default`
