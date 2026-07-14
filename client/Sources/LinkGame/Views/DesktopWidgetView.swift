import SwiftUI
import AppKit

/// 浮动桌面挂件窗口 —— 不依赖 WidgetKit，独立 NSWindow 实现
class WidgetWindowController: NSObject, NSWindowDelegate {
    static let shared = WidgetWindowController()
    weak var window: NSWindow?

    func show() {
        guard window == nil else {
            window?.makeKeyAndOrderFront(nil)
            return
        }

        let view = DesktopWidgetContent()
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: 200, height: 200)

        let win = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 200, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        win.contentView = hosting
        win.backgroundColor = .clear
        win.isOpaque = false
        win.hasShadow = true
        win.level = .floating
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        win.isMovableByWindowBackground = true
        win.isReleasedWhenClosed = false
        win.animationBehavior = .none
        win.delegate = self
        win.title = "泓泓看挂件"
        win.makeKeyAndOrderFront(nil)

        self.window = win
    }

    func hide() {
        guard let win = window else { return }
        win.delegate = nil
        win.orderOut(nil)
        window = nil
    }

    func windowWillClose(_ notification: Notification) {
        if let win = window {
            win.delegate = nil
        }
        window = nil
    }
}

/// 桌面挂件内容
struct DesktopWidgetContent: View {
    @State private var skin = WidgetSkin.defaultSkin
    @State private var coins: Int = 0
    @State private var ownedCount: Int = 1
    @State private var displayName: String = ""

    var body: some View {
        let s = skin
        let hasImage = s.imageName != nil && loadImage(s.imageName!) != nil
        let cornerRadius: CGFloat = s.borderStyle == "none" ? 0 : 12

        ZStack {
            // 背景：有图用图，没图用纯色
            if hasImage, let img = loadImage(s.imageName!) {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                // 底部渐变遮罩
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.55)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 100)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            } else {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(s.bgColor)
            }

            // 文字层
            VStack(spacing: 4) {
                // 标签头
                HStack(spacing: 3) {
                    Image(systemName: s.badgeIcon)
                        .font(.system(size: 12, weight: .bold))
                    Text("泓泓看")
                        .font(.system(size: 12, weight: .bold, design: fontDesign(for: s.fontName)))
                        .fixedSize()
                }
                .foregroundColor(s.fgColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(s.accent))

                Spacer().frame(height: 4)

                // 皮肤名称
                Text(s.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(s.fgColor)

                // 用户昵称
                if !displayName.isEmpty {
                    Text("@\(displayName)")
                        .font(.system(size: 10))
                        .foregroundColor(s.fgColor.opacity(0.7))
                        .fixedSize()
                }

                Spacer().frame(height: 2)

                // 金币
                HStack(spacing: 3) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 11))
                    Text("\(coins)")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                }
                .foregroundColor(s.accent)

                // 收集数量
                Text("已收集\(ownedCount)个挂件")
                    .font(.system(size: 10))
                    .foregroundColor(s.fgColor.opacity(0.6))
            }
            .padding(12)
        }
        .frame(width: 200, height: 200)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 3)
        .onAppear { loadData() }
        .onReceive(NotificationCenter.default.publisher(for: .widgetDataChanged)) { _ in
            loadData()
        }
    }

    private func loadImage(_ name: String) -> NSImage? {
        let paths: [String] = [
            Bundle.main.resourcePath ?? "",
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources").path,
        ]
        for base in paths {
            let full = base + "/" + name
            if !base.isEmpty, let img = NSImage(contentsOfFile: full) { return img }
        }
        return nil
    }

    private func loadData() {
        let defaults = UserDefaults(suiteName: WidgetDataProvider.suiteName) ?? .standard
        let activeID = defaults.string(forKey: WidgetDataProvider.activeSkinIDKey) ?? "default"
        skin = WidgetSkin.all.first(where: { $0.id == activeID }) ?? .defaultSkin
        coins = defaults.integer(forKey: WidgetDataProvider.currencyBalanceKey)
        let purchased = defaults.stringArray(forKey: WidgetDataProvider.purchasedSkinsKey) ?? ["default"]
        ownedCount = purchased.count
        displayName = defaults.string(forKey: WidgetDataProvider.nicknameKey) ?? ""
    }

    private func fontDesign(for name: String) -> Font.Design {
        switch name {
        case "monospaced": return .monospaced
        case "rounded": return .rounded
        case "serif": return .serif
        default: return .default
        }
    }
}
