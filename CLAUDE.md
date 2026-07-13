# 泓泓看 Mac App 游戏

## 项目结构

```
~/linkgame/
├── server/                  # Go 后端 (端口 9090)
│   ├── main.go
│   ├── handlers/            # auth.go, game.go, health.go, avatar.go
│   ├── middleware/          # auth.go, jwt.go
│   ├── models/              # user.go, score.go, level.go, password_reset.go, currency.go
│   ├── times/               # 北京时区工具 (times.Now())
│   ├── email/               # smtp.go (QQ邮箱 SMTP)
│   └── db/                  # sqlite.go, migrations/ (001~008)
├── client/                  # macOS 客户端 (SwiftUI)
│   ├── Package.swift
│   ├── LinkGame.app         # .app 包
│   └── Sources/LinkGame/
│       ├── App.swift
│       ├── Views/           # ContentView, GameView, LoginView, LeaderboardView,
│       │                      SettingsView, ForgotPasswordView, DinoRunnerView,
│       │                      AvatarView, GameHubView, HistoryView,
│       │                      AppLogo, AppBackground, PixelArtBackground,
│       │                      WallpaperButton, ClickableModifier
│       ├── Game/            # LinkEngine(路径算法), Board, GameState
│       ├── Network/         # APIClient, ServerManager (App内管理服务器进程)
│       └── Models/          # User, Score, Level, Theme, IconSet, ThemeManager,
│                              AccountManager, MusicManager, WallpaperManager
└── personalization/         # 个性化扩展
    ├── CLAUDE.md
    ├── themes/default/      # 默认主题（描边/特效/图标/配色）
    └── minigames/           # 登录页小游戏（独立于主题）
```

桌面快捷方式：`~/Desktop/泓泓看.app`

## 时区

所有时间使用 **北京时间 (UTC+8)**：
- Go 后端：`times.Now()` 强制返回北京时间，INSERT 显式传入 `created_at`
- SQLite：启动命令设置 `TZ=Asia/Shanghai`
- Swift 客户端：`DateFormatter` 设置 `timeZone = Asia/Shanghai` 解析服务器时间

## App 自动管理服务器

客户端打开时**自动启动** Go 后端，退出时自动停止。无需手动管理终端。

启动流程：`打开 App → 显示加载动画 → 服务器就绪 → 显示登录页`

如果打开 App 后显示"启动失败"，说明 `linkgame-server` 二进制不在 .app 的 Resources 目录或 `~/linkgame/server/` 下。

## 编译 & 部署

```bash
# 1. 编译后端
cd ~/linkgame/server && GOPROXY=https://goproxy.cn,direct go build -o linkgame-server .

# 2. 编译客户端 + 部署（含图标和服务端二进制）
cd ~/linkgame/client && swift build && \
  cp .build/debug/LinkGame LinkGame.app/Contents/MacOS/LinkGame && \
  cp ~/linkgame/server/linkgame-server LinkGame.app/Contents/Resources/linkgame-server

# 图标变更后需重新生成：
# cd ~/linkgame/client && iconutil -c icns icon.iconset -o LinkGame.app/Contents/Resources/AppIcon.icns

# 3. 启动
open ~/linkgame/client/LinkGame.app

# 停止客户端（服务器自动跟随停止）
pkill -f "MacOS/LinkGame"
```

**注意：** `Info.plist` 一旦创建后无需每次部署都更新，但首次部署时必须存在（含 `CFBundleIconFile` 键）。

## 单独启动后端（调试用）

```bash
cd ~/linkgame/server && TZ=Asia/Shanghai QQ_MAIL_AUTH_CODE=qbiezwuwwfvbeaib ./linkgame-server &
pkill linkgame-server  # 停止
```

## API 列表

| API | 方法 | 需要登录 | 功能 |
|-----|------|---------|------|
| `/api/health` | GET | 否 | 服务器状态 |
| `/api/register` | POST | 否 | 注册 `{username, email, password}` |
| `/api/login` | POST | 否 | 登录 → token |
| `/api/forgot-password` | POST | 否 | 发送重置验证码到邮箱 |
| `/api/reset-password` | POST | 否 | 验证码 + 新密码重置 |
| `/api/bind-email` | POST | 是 | 绑定/修改邮箱 |
| `/api/daily` | GET | 否 | 每日关卡 |
| `/api/score` | POST | 是 | 提交分数 |
| `/api/leaderboard` | GET | 否 | 排行榜（?level_id=classic&limit=50，默认过滤本周） |
| `/api/my/stats` | GET | 是 | 个人统计 |
| `/api/my/history` | GET | 是 | 对局历史（最近100局） |
| `/api/me/nickname` | POST | 是 | 更新昵称 |
| `/api/me/avatar/upload` | POST | 是 | 上传头像图片 |
| `/api/avatars/{filename}` | GET | 否 | 获取头像图片 |
| `/api/me/daily-unlock` | POST | 是 | 解锁每日挑战（扣5000金币） |
| `/api/me/currency-logs` | GET | 是 | 金币流水记录（最近50条） |

认证：`Authorization: Bearer <token>`

## 功能清单

| 功能 | 状态 |
|------|------|
| 连连看核心玩法（BFS路径匹配） | ✅ |
| 7 个后端 API | ✅ |
| 注册/登录（邮箱必填） | ✅ |
| 邮箱找回密码（QQ SMTP） | ✅ |
| 绑定/修改邮箱 | ✅ |
| 保存账号+记住密码（本地加密） | ✅ |
| 每日挑战（后端统一关卡） | ✅ |
| 排行榜（周榜 + 分模式独立） | ✅ |
| 主题切换（默认蓝白 / 暗黑霓虹） | ✅ |
| 登录页跑酷小游戏（彩蛋） | ✅ |
| 头像系统（图片上传，点击主屏头像更换） | ✅ |
| 昵称系统 | ✅ |
| 对局历史记录（分模式独立，最近100局） | ✅ |
| 货币系统（经典得分=金币，流水记录） | ✅ |
| 每日挑战付费解锁（5000金币） | ✅ |
| 失败对局记录 | ✅ |
| 渐变背景 + 毛玻璃卡片 | 已替换为像素风动态背景 + 壁纸切换系统 |
| 隐藏标题栏 | ✅ |
| 背景音乐（程序化生成，五声音阶） | ✅ |

## 个性化

详见 `~/linkgame/personalization/CLAUDE.md`

| 编号 | 分类 | 扩展 | 状态 |
|------|------|------|------|
| 001 | 描边 | 白色悬停描边 | ✅ |
| 002 | 描边 | 连线消除 | ✅ |
| 003 | 特效 | 啪嗒消失+冲击波+震屏 | ✅ |
| T01 | 主题 | 默认蓝白 | ✅ |
| E01 | 图标 | 水果动物 | ✅ |
| M01 | 小游戏 | 登录页跑酷 | ✅ |

## 数据库

SQLite：`~/.linkgame/data.db`

迁移记录：
| 编号 | 文件 | 内容 |
|------|------|------|
| 001 | `001_init.sql` | 建表 users, scores, daily_levels |
| 002 | `002_email_reset.sql` | users 加 email_reset_code |
| 003 | `003_avatar.sql` | users 加 avatar |
| 004 | `004_nickname.sql` | users 加 nickname |
| 005 | `005_week.sql` | scores 加 week（周榜） |
| 006 | `006_currency.sql` | users 加 currency（金币） |
| 007 | `007_daily_unlock.sql` | users 加 daily_unlocked |
| 008 | `008_currency_log.sql` | 新建 currency_logs 流水表 |

## UI 布局

```
┌─────────────────────────────┐
│         🎮 Logo             │
│         泓泓看              │
│      你好，username         │
│                             │
│     ┌──────────┐            │
│     │ 开始游戏  │            │
│     │ 每日挑战  │            │
│     └──────────┘            │
│                             │
│          我的战绩            │
│    10局  15200分  45s       │
│                             │
│ 🏆排行榜  🎨主题 │ ⚙设置 🚪退出 │
└─────────────────────────────┘
```

## 壁纸系统（2026-07-13）

### 架构

- **`WallpaperManager`**（`Models/WallpaperManager.swift`）：`ObservableObject` 单例，管理当前壁纸选择，UserDefaults 持久化
- **`Wallpaper` enum**：所有可选壁纸（`.pixelArt` 像素风 / `.gradient` 渐变紫），每个 case 含 `icon` 和 `rawValue`
- **`PixelArtBackground`**（`Views/PixelArtBackground.swift`）：壁纸感知包装器，根据 `WallpaperManager.current` 渲染对应场景
- **`PixelArtScene`**：像素风动画场景（蓝天色带 + 流动像素云 + 摆动的草地 + 两个小风车）
- **`WallpaperButton`**：全局壁纸选择按钮，`Menu` 弹出所有选项，当前选中打 checkmark

### 按钮位置

| 页面 | 位置 |
|------|------|
| ContentView | 右上角，金币按钮左边 |
| LoginView | 右上角，独立一行 |
| GameView | header bar 右上角，排行榜按钮左边 |

### 添加新壁纸

1. `WallpaperManager.swift` → `Wallpaper` enum 加新 case（设定 `rawValue` 名称和 `icon`）
2. `PixelArtBackground.swift` → `PixelArtBackground.body` 的 `switch` 加新分支渲染

### 像素风场景实现细节

- `TimelineView(.animation)` + `Canvas` 驱动 60fps 渲染
- 天空：8 种蓝色水平 2px 色带（pixelSize=8pt）
- 白云：4 朵不同大小的像素图案，speed 0.8-1.4 快速漂浮，底部带阴影像素
- 草地：底部 16px 行，4 种绿色交错，顶部 3 行草叶正弦波微摆
- 风车：左右各一个（col=8 和 col=cols-8），1px 细杆，2x2 轮毂，4 片旋转叶片（7px 长）
- 风车底座嵌入草地（`bodyBot = grassStartRow + 4`）

## 待办 / 未来方向

### 管理员后台
- 特定账号标记为 admin，登录后显示「管理面板」
- 查看所有用户列表（id/用户名/邮箱/金币/注册时间）
- 查看任意用户的分数记录、金币流水
- 简单统计：DAU、总对局数、各模式参与度
- 目前只能直接 `sqlite3 ~/.linkgame/data.db` 查库

### 分发
- **GitHub Release（开源分发）**：代码签名 + 公证 + 打包 `.dmg`，不需要改架构
- **App Store 上架**：沙盒禁止 `Process()` 启子进程，需改为后端上云或用 Swift 重写后端逻辑

## 开发踩坑记录

### macOS Sheet 布局（反复犯错，务必遵守）
- Sheet 内用 `List`，不要用 `ScrollView` + `LazyVStack`（标题栏会跑到中间）
- **所有弹窗必须用统一的头部模式**：`HStack { Text(标题).font(.title2.bold()) + Spacer() + Button("关闭") { dismiss() }.buttonStyle(.plain) }`，然后 `Divider()`，参考 `LeaderboardView.swift`
- 不要在底部放关闭按钮，所有关闭按钮都在右上角统一位置
- 不要设固定 `.frame(width:height:)`，用 LeaderboardView 的无 frame 模式
- **禁止嵌套 sheet**（ContentView sheet → 子 view sheet），会导致卡死。用回调模式：子 view 回调 → ContentView 管理 sheet

### 后端每日关卡
- 布局必须留空边框（外层全 0），尺寸 8x12（含边框），内部 6x10
- 棋子类型 1..20 整数，匹配客户端 IconSet
- 旧 `[[String]]` 格式需自愈迁移

### HTTP 方法匹配（刚踩的大坑）
- **后端路由和客户端请求的 HTTP 方法必须一致**
- `APIClient` 的 `post()` 发的是 `POST`，后端 `mux.HandleFunc("PUT /api/...", ...)` 只匹配 `PUT`
- 方法不匹配 → 请求被 404 吞掉 → 保存静默失败 → 数据丢失
- **规则：新增 API 时统一用 POST**，因为 `APIClient` 目前只有 `get()` 和 `post()`

### 操作纪律
- **严禁 `rm ~/.linkgame/data.db`** 删库，用 ALTER TABLE / UPDATE 迁移
- 每次部署完自动重启 App：`pkill -f "MacOS/LinkGame" && open ~/linkgame/client/LinkGame.app`
- 点「玩法中心」→ 回调通知 ContentView → ContentView 统一管理所有 sheet
- 涉及数据保存的 bug，先 `curl` 测试后端 API 是否正常返回，再排查客户端

### 排行榜体系（2026-07-12 重构）
- **周榜机制**：分数提交时自动标记 ISO 周（`2026-W28`），查询默认只取本周数据
- **分模式独立**：`level_id` 改为模式前缀（`classic`/`timed`/`step`/`daily-YYYY-MM-DD`）
- **入口**：
  - 主屏排行榜 → 经典模式本周排行
  - 玩法中心每日挑战卡片 → 该日挑战排行
  - 玩法中心限时模式卡片 → 限时模式本周排行
  - 游戏中排行榜 → 当前模式排行

### 货币系统（2026-07-12）
- **获取方式**：完成经典模式对局，得分即金币（7000分 = $7000）
- **消费方式**：解锁每日挑战（5000金币），后续可扩展更多消费场景
- **流水记录**：`currency_logs` 表记录每笔变动（收入/支出+原因），点击主屏金币查看
- **数据安全**：`users.currency` 只增不减（除了消费），**绝不重置或删除用户金币**
- **按账号隔离**：每个账号独立货币余额和解锁状态

### 玩法中心当前模式
- 每日挑战：后端统一关卡（`/api/daily`），需5000金币解锁（一次解锁永久有效）
- 限时模式：120秒倒计时，本地生成布局，免费开放
- 经典模式由主屏「开始游戏」进入，不在玩法中心

### Go 中文字符长度陷阱
- `len("喜欢懒羊羊")` 返回 15（字节数），不是 5（字符数）
- 验证中文字符长度必须用 `utf8.RuneCountInString()`
- 同样的坑也会出现在用户名验证上

### HTTP 状态码检查
- `URLSession.shared.data(for:)` 不抛异常即使返回 400/500
- `APIClient.post/get` 必须检查 `HTTPURLResponse.statusCode >= 400`，解析 error 消息并 throw

### 图片上传崩溃：血泪教训（已修复，2026-07-12）

**根因：** `swiftSettings: [.unsafeFlags(["-Xfrontend", "-disable-availability-checking"])]`

这个 flag 静默破坏运行时 ABI，导致 Foundation 操作（String 编码、URLRequest、URLSession 等）随机 SIGSEGV。删掉 flag 即可。

**为什么极其难查（耗时 2h+，20+ 次尝试）：**

| 症状 | 误导效果 |
|------|----------|
| SIGSEGV，无有用错误信息 | 只能看 .ips 崩溃报告，PC=0 空指针 |
| 崩溃位置每次都变 | 先后指向 Task closure、DispatchQueue.main、NSItemProvider thunk、Button action |
| 部分 Foundation API 正常 | `URL(string:)`、`UUID()`、`Data()` 能工作，`String.data(using:)` 就崩 |
| 主线程/子线程都崩 | 误导认为是线程安全问题，试了 DispatchQueue 各种组合 |
| 编译零报错 | 没有任何提示这个 flag 有问题 |

**排查方法论（隔离测试法）：**

1. 最简测试：拖拽 → 只 `print("ok")` → ✅ 不崩
2. + `DispatchQueue.main.async` → ✅ 不崩
3. + 访问 `auth.token` → ✅ 不崩
4. + `"hello".data(using: .utf8)!` → ❌ 崩（确认 Foundation 编码操作崩溃）
5. + `UUID()`、`URL(string:)`、`Data()` → ✅ 不崩（部分 Foundation API 正常）
6. + `URLRequest`、`Data.append` → ❌ 崩
7. 换 `loadItem` API → ❌ 崩
8. `DispatchQueue.global().async` 包装 → ❌ 崩
9. `NotificationCenter` 解耦 + `.onReceive` → ❌ 崩
10. 终于怀疑编译配置 → 删 flag → ✅ **成功！**

**最终架构：** 拖拽上传（`.onDrop` + `loadItem` → NotificationCenter → `.onReceive` → URLSession）

**教训：**
- `-disable-availability-checking` **绝不能用于生产代码**
- 遇到 SIGSEGV 先检查编译配置
- 逐步隔离是定位疑难 bug 的最有效方法
- macOS 14.6 (23G93) + Swift 5.9 不需要此 flag

### 时区漂移修复（2026-07-12）

**问题：** 项目完全没有时区处理。`time.Now()` 和 SQLite `datetime('now')` 依赖系统本地时间，换环境可能漂移。Swift 客户端 `ISO8601DateFormatter` 尝试解析 ISO 8601 格式，但服务器存的是 `"2006-01-02 15:04:05"` 格式（无 T 分隔符、无时区后缀），解析永远失败，最终 fallback 到 `String(raw.prefix(16))` 截断显示。

**三层保障：**

| 层 | 位置 | 机制 |
|----|------|------|
| 启动命令 | `TZ=Asia/Shanghai` | SQLite `datetime('now')` 默认值用北京时间 |
| Go 代码 | `server/times/times.go` | `times.Now()` 封装 `time.Now().In(Beijing)`，强制 UTC+8 |
| Swift 客户端 | `DateFormatter.timeZone` | 解析和显示显式指定 `Asia/Shanghai` |

**Go 端改动：**
- 新增 `server/times/` 包，提供 `times.Now()` 和 `times.NowString()`
- 替换全部 7 处 `time.Now()` 调用（handlers/game.go, models/score.go, models/password_reset.go, middleware/jwt.go）
- 所有 INSERT 语句显式传入 `created_at`（users, scores, daily_levels, currency_logs），不再依赖 SQLite 默认值

**Swift 端改动：**
- `HistoryView.formattedDate()` — 改为解析 `"yyyy-MM-dd HH:mm:ss"` 格式，指定 `Asia/Shanghai` 时区
- `CurrencyLogView.formatDate()` — 同上，不再用 `String.prefix(16)` 简单截断
- `GameHubView.dailyLeaderID()` — `DateFormatter` 指定 `Asia/Shanghai`

**教训：**
- 服务器时间存储格式要统一，不要混用 SQLite 默认值和 Go 生成值
- `ISO8601DateFormatter` 只认 `"2026-07-12T15:04:05Z"` 格式，不认 SQLite 的 `"2026-07-12 15:04:05"`
- Swift 的 `DateFormatter` 默认用系统时区，需要显式设置源时区才能正确解析

### App 内嵌服务器（2026-07-12）

**目标：** 关掉终端后 App 仍能正常使用。改为 App 启动时自动开启 Go 后端，退出时自动关闭。

**架构：**
- `ServerManager`（`Network/ServerManager.swift`）：管理 `Process()` 生命周期
- `AppDelegate.applicationWillTerminate`：App 退出时停服
- 二进制查找顺序：`App/Contents/Resources/` → `~/linkgame/server/`

**关键坑：`Process.environment` 会替换整个环境**

```swift
// ❌ 错误：只传了自定义变量，缺少 HOME/PATH 等
serverProc.environment = ["QQ_MAIL_AUTH_CODE": "...", "TZ": "Asia/Shanghai"]
// Go 服务器 os.UserHomeDir() 找不到 HOME，进程立即崩溃退出

// ✅ 正确：继承父进程环境，只覆盖需要的变量
var env = ProcessInfo.processInfo.environment  // 继承全部系统环境
env["QQ_MAIL_AUTH_CODE"] = "qbiezwuwwfvbeaib"
env["TZ"] = "Asia/Shanghai"
serverProc.environment = env
```

**Swift 5.9 `Task {}` 类型推断 Bug：**
在 `@MainActor` 类的非 async 方法中，`Task { ... }` 会报 "type of expression is ambiguous without a type annotation"。这是 Swift 5.9 的已知问题，与 `Process` 局部变量名无关。解决方案：改用 `DispatchQueue` + `URLSession.dataTask` 回调模式（参见 `pollHealth` 实现）。

**macOS App Bundle 注意事项：**
- `.app` 必须有 `Contents/Info.plist`，否则 `open` 命令启动时 Bundle 解析可能异常
- SwiftPM 编译的裸二进制复制到 `.app/Contents/MacOS/` 后，需同时创建 `Info.plist`
- 开发调试时可直接从终端运行二进制（此时 `Bundle.main.resourcePath` 可能为空），需保留 dev path fallback

### Info.plist 污染导致 Dock 图标异常（2026-07-12）

**现象：** Dock 栏显示默认占位图标，而不是自定义 App 图标。

**根因：**
1. `Info.plist` 末尾被 bash 的 heredoc `<< 'PLIST'` 写入时意外追加了 `echo "Info.plist created"` 一行，XML 解析失败，整个 plist 被忽略
2. `Info.plist` 缺少 `CFBundleIconFile` 键，macOS 不知道用哪个图标文件

**修复：**
- 重写 `Info.plist`，确保 XML 完整且包含 `<key>CFBundleIconFile</key><string>AppIcon</string>`
- `killall Dock` 刷新 Dock 缓存（否则即使 plist 修复了，Dock 仍显示旧图标）

**教训：**
- 写文件时注意 heredoc 重定向语法，确保不会把 shell 命令也写进去
- macOS 图标生效链路：`Info.plist → CFBundleIconFile → Resources/AppIcon.icns → Dock 缓存`
- plist 任何一点 XML 语法错误都会导致整个文件被忽略，且没有任何报错提示

### 程序化背景音乐（2026-07-12）

**目标：** 零外部音频文件，用代码生成环境音乐。AVAudioEngine + AVAudioSourceNode 实时渲染五声音阶旋律。

**架构：**
- `MusicManager`（`Models/MusicManager.swift`）：单例 `ObservableObject`，管理音频引擎
- 五声音阶（C4 D4 E4 G4 A4 C5），BPM 72，正弦波旋律 + 低音 + 铺底
- 混响（`AVAudioUnitReverb`，LargeHall 预设）
- 音量/静音通过 `@Published` 属性 + UserDefaults 持久化
- 登录页底部和设置页均有控制入口

**关键坑 1：AVAudioSourceNode 必须先 attach 再 connect**

```swift
// ❌ 错误：未 attach 就 connect → NSException 崩溃
let srcNode = AVAudioSourceNode(format: f) { ... }
engine.connect(srcNode, to: reverb, format: f)  // crash!

// ✅ 正确
engine.attach(srcNode)
engine.connect(srcNode, to: reverb, format: f)
```

`AVAudioPlayerNode`/`AVAudioUnitReverb` 等也需要 attach。忘记 attach 会导致 Objective-C NSException（`com.apple.coreaudio.avfaudio`），Swift 的 do-catch 无法捕获，App 直接崩溃。

**关键坑 2：mainMixerNode.volume 对 AVAudioSourceNode 可能无效**

通过 `engine.mainMixerNode.volume` 控制音量在某些情况下不生效（尤其是 AVAudioSourceNode 路径）。解决方案：在渲染回调中直接乘以 `masterGain` 变量，音量控制完全在采样层实现。

```swift
// render callback 中
let sample = (melody + bass + pad) * 0.7 * masterGain
```

**关键坑 3：@AppStorage 在 ObservableObject 中不可靠**

`@AppStorage` 需 SwiftUI View 上下文才能正确发布变更。在 plain `ObservableObject` singleton 中，UI 绑定可能不更新。改用 `@Published` + 手动 `UserDefaults` 同步。
