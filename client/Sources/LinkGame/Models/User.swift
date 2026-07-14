import Foundation

struct User: Codable {
    let id: Int64
    let username: String
    let nickname: String?
    let email: String?
    let avatar: String?
    let currency: Int64?
    let dailyUnlocked: Bool?
    let createdAt: String?

    var displayName: String {
        if let nick = nickname, !nick.isEmpty { return nick }
        return username
    }

    var coins: Int64 { currency ?? 0 }
    var isDailyUnlocked: Bool { dailyUnlocked ?? false }

    enum CodingKeys: String, CodingKey {
        case id, username, nickname, email, avatar, currency
        case dailyUnlocked = "daily_unlocked"
        case createdAt = "created_at"
    }
}

struct AuthResponse: Codable {
    let token: String
    let user: User?
    let error: String?
}

@MainActor
class AuthState: ObservableObject {
    @Published var token: String?
    @Published var currentUser: User?
    @Published var errorMessage: String?
    @Published var forgotMessage: String?

    var isLoggedIn: Bool { token != nil }

    func login(username: String, password: String) async {
        errorMessage = nil
        do {
            let resp: AuthResponse = try await APIClient.post(
                "/api/login",
                body: ["username": username, "password": password]
            )
            if let error = resp.error {
                errorMessage = error
            } else {
                token = resp.token
                currentUser = resp.user
                if let user = resp.user {
                    AccountManager.shared.updateAccountInfo(
                        username: user.username,
                        avatar: user.avatar ?? "",
                        nickname: user.nickname ?? ""
                    )
                }
                syncWidgetData()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func register(username: String, email: String, password: String) async {
        errorMessage = nil
        do {
            let resp: AuthResponse = try await APIClient.post(
                "/api/register",
                body: ["username": username, "email": email, "password": password]
            )
            if let error = resp.error {
                errorMessage = error
            } else {
                token = resp.token
                currentUser = resp.user
                if let user = resp.user {
                    AccountManager.shared.updateAccountInfo(
                        username: user.username,
                        avatar: user.avatar ?? "",
                        nickname: user.nickname ?? ""
                    )
                }
                syncWidgetData()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func forgotPassword(email: String) async {
        errorMessage = nil
        forgotMessage = nil
        do {
            let resp = try await APIClient.forgotPassword(email: email)
            forgotMessage = resp["message"] ?? resp["error"] ?? "已发送"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetPassword(email: String, code: String, newPassword: String) async {
        errorMessage = nil
        do {
            let resp = try await APIClient.resetPassword(
                email: email, code: code, newPassword: newPassword
            )
            forgotMessage = resp["message"] ?? resp["error"] ?? "完成"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func logout() {
        token = nil
        currentUser = nil
        // 挂件是账号专属的，退出时隐藏并清数据
        WidgetWindowController.shared.hide()
        WidgetDataProvider.clear()
    }

    /// 登录后同步挂件数据（皮肤/金币）到共享 UserDefaults
    func syncWidgetData() {
        guard let user = currentUser else { return }
        WidgetDataProvider.Writer.setUserInfo(username: user.username, nickname: user.displayName)
        WidgetDataProvider.Writer.setCurrencyBalance(Int(user.coins))
        // 异步从后端拉取皮肤列表
        Task {
            if let remote: WidgetSkinsResponse = try? await APIClient.get("/api/me/widget-skins") {
                WidgetDataProvider.Writer.sync(
                    currency: Int(user.coins),
                    purchasedSkins: remote.skins,
                    activeSkinID: remote.activeSkinID,
                    username: user.username,
                    nickname: user.displayName
                )
            }
        }
    }
}
