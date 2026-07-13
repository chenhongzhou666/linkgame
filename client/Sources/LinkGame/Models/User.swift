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
    }
}
