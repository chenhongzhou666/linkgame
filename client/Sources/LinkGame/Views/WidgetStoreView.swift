import SwiftUI

/// 挂件商店视图
struct WidgetStoreView: View {
    @EnvironmentObject var auth: AuthState
    @Environment(\.dismiss) var dismiss
    @State private var skins = WidgetSkin.all
    @State private var purchasedIDs: Set<String> = ["default"]
    @State private var activeSkinID = "default"
    @State private var isBuying = false
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var userCoins: Int64 = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("🎨 桌面挂件商店")
                    .font(.title2.bold())
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundStyle(.yellow)
                    Text("\(userCoins)")
                        .font(.title3.bold())
                        .foregroundStyle(.yellow)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(.ultraThinMaterial))

                Button("关闭") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Divider().padding(.top, 12)

            // 浮动挂件开关
            HStack(spacing: 8) {
                Image(systemName: "macwindow.on.rectangle")
                    .foregroundStyle(.orange)
                Text("浮动桌面挂件（不依赖系统 Widget）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: {
                    WidgetWindowController.shared.show()
                }) {
                    Label("显示挂件", systemImage: "rectangle.inset.filled.and.cursorarrow")
                        .font(.caption.bold())
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                Button(action: {
                    WidgetWindowController.shared.hide()
                }) {
                    Text("隐藏")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            // Skin grid
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                    ForEach(skins) { skin in
                        SkinCard(
                            skin: skin,
                            isOwned: purchasedIDs.contains(skin.id),
                            isActive: activeSkinID == skin.id,
                            coins: userCoins,
                            onBuy: { buySkin(skin) },
                            onActivate: { activateSkin(skin) }
                        )
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 520, height: 480)
        .onAppear {
            userCoins = auth.currentUser?.coins ?? 0
            loadPurchasedSkins()
        }
        .alert(alertMessage, isPresented: $showAlert) {
            Button("确定", role: .cancel) {}
        }
    }

    // MARK: - Actions

    private func loadPurchasedSkins() {
        // 先从共享 UserDefaults 读
        let sharedIDs = WidgetDataProvider.purchasedSkinIDs
        purchasedIDs = Set(sharedIDs)
        activeSkinID = WidgetDataProvider.sharedDefaults.string(forKey: WidgetDataProvider.activeSkinIDKey) ?? "default"
        // 也从后端同步（在线时）
        Task {
            if let remote: WidgetSkinsResponse = try? await APIClient.get("/api/me/widget-skins") {
                purchasedIDs = Set(remote.skins)
                activeSkinID = remote.activeSkinID
                WidgetDataProvider.Writer.sync(
                    currency: Int(userCoins),
                    purchasedSkins: Array(remote.skins),
                    activeSkinID: remote.activeSkinID,
                    username: auth.currentUser?.username ?? "",
                    nickname: auth.currentUser?.displayName ?? ""
                )
            }
        }
    }

    private func buySkin(_ skin: WidgetSkin) {
        guard !isBuying else { return }
        isBuying = true

        Task {
            do {
                let resp: BuySkinResponse = try await APIClient.post(
                    "/api/me/widget-skins/buy",
                    body: ["skin_id": skin.id]
                )
                // 更新本地状态
                purchasedIDs.insert(skin.id)
                userCoins = resp.currency
                if var user = auth.currentUser {
                    user = User(
                        id: user.id,
                        username: user.username,
                        nickname: user.nickname,
                        email: user.email,
                        avatar: user.avatar,
                        currency: resp.currency,
                        dailyUnlocked: user.dailyUnlocked,
                        trophies: user.trophies,
                        createdAt: user.createdAt
                    )
                    auth.currentUser = user
                }
                // 同步到共享 UserDefaults
                WidgetDataProvider.Writer.addPurchasedSkin(skin.id)
                WidgetDataProvider.Writer.setCurrencyBalance(Int(resp.currency))
                alertMessage = "购买成功！已解锁「\(skin.name)」"
                showAlert = true
            } catch {
                alertMessage = "购买失败：\(error.localizedDescription)"
                showAlert = true
            }
            isBuying = false
        }
    }

    private func activateSkin(_ skin: WidgetSkin) {
        activeSkinID = skin.id
        WidgetDataProvider.Writer.setActiveSkin(skin.id)
        // 同步到后端，保证重登不丢失
        Task {
            let _: ActivateSkinResponse? = try? await APIClient.post(
                "/api/me/widget-skins/activate",
                body: ["skin_id": skin.id]
            )
        }
        alertMessage = "已切换到「\(skin.name)」，挂件立即更新"
        showAlert = true
    }
}

// MARK: - Skin Card

struct SkinCard: View {
    let skin: WidgetSkin
    let isOwned: Bool
    let isActive: Bool
    let coins: Int64
    let onBuy: () -> Void
    let onActivate: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            // Preview
            ZStack {
                if let img = skin.imageName, let nsImg = loadImage(img) {
                    Image(nsImage: nsImg)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack {
                        Spacer()
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.5)],
                            startPoint: .top, endPoint: .bottom
                        )
                        .frame(height: 40)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    // 底部标签
                    VStack {
                        Spacer()
                        Text("泓泓看")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.bottom, 6)
                    }
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(skin.bgColor)

                    VStack(spacing: 3) {
                        Image(systemName: skin.badgeIcon)
                            .font(.system(size: 18))
                            .foregroundColor(skin.accent)
                        Text("泓泓看")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(skin.fgColor)
                        // Mini zipper
                        HStack(spacing: 1) {
                            ForEach(0..<6, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(i % 2 == 0 ? skin.accent : skin.fgColor.opacity(0.3))
                                    .frame(width: 4, height: 1.5)
                            }
                        }
                    }
                }

                if skin.borderStyle == "shadow" {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(skin.accent.opacity(0.5), lineWidth: 1.5)
                }

                if isActive {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.green)
                                .background(Circle().fill(.white).frame(width: 14, height: 14))
                                .padding(4)
                        }
                        Spacer()
                    }
                }
            }
            .frame(height: 80)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(skin.accent.opacity(0.3), lineWidth: 1)
            )

            // Info
            VStack(spacing: 2) {
                Text(skin.name)
                    .font(.caption.bold())
                Text(skin.description)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if isOwned {
                    Button(action: onActivate) {
                        Text(isActive ? "✓ 使用中" : "使用")
                            .font(.caption2.bold())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(isActive ? .green : .blue)
                    .disabled(isActive)
                } else {
                    Button(action: onBuy) {
                        HStack(spacing: 2) {
                            Image(systemName: "dollarsign.circle.fill")
                                .font(.system(size: 9))
                            Text("\(skin.price)")
                        }
                        .font(.caption2.bold())
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.yellow)
                    .disabled(coins < Int64(skin.price))
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
    }
}

// MARK: - API Response Types

struct WidgetSkinsResponse: Codable {
    let skins: [String]
    let activeSkinID: String

    enum CodingKeys: String, CodingKey {
        case skins
        case activeSkinID = "active_skin_id"
    }
}

struct BuySkinResponse: Codable {
    let currency: Int64
    let skinID: String

    enum CodingKeys: String, CodingKey {
        case currency
        case skinID = "skin_id"
    }
}

struct ActivateSkinResponse: Codable {
    let skinID: String

    enum CodingKeys: String, CodingKey {
        case skinID = "skin_id"
    }
}

private func loadImage(_ name: String) -> NSImage? {
    let paths = [
        Bundle.main.resourcePath ?? "",
        Bundle.main.bundleURL.appendingPathComponent("Contents/Resources").path,
    ]
    for base in paths {
        let full = base + "/" + name
        if !base.isEmpty, let img = NSImage(contentsOfFile: full) { return img }
    }
    return nil
}
