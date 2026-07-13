import Foundation

struct SavedAccount: Codable, Identifiable {
    var id: String { username }
    let username: String
    var hasSavedPassword: Bool
    var avatar: String = ""
    var nickname: String = ""

    var displayName: String {
        if !nickname.isEmpty { return nickname }
        return username
    }
}

class AccountManager: ObservableObject {
    static let shared = AccountManager()

    @Published var accounts: [SavedAccount] = []

    private let accountsKey = "saved_accounts"
    private let passwordPrefix = "pwd_"

    init() {
        loadAccounts()
    }

    func loadAccounts() {
        guard let data = UserDefaults.standard.data(forKey: accountsKey),
              let list = try? JSONDecoder().decode([SavedAccount].self, from: data) else {
            accounts = []
            return
        }
        accounts = list
    }

    private func saveAccountList() {
        guard let data = try? JSONEncoder().encode(accounts) else { return }
        UserDefaults.standard.set(data, forKey: accountsKey)
    }

    func addAccount(username: String, password: String?, savePassword: Bool, avatar: String = "", nickname: String = "") {
        if let idx = accounts.firstIndex(where: { $0.username == username }) {
            if !avatar.isEmpty { accounts[idx].avatar = avatar }
            if !nickname.isEmpty { accounts[idx].nickname = nickname }
            accounts[idx].hasSavedPassword = savePassword
        } else {
            accounts.append(SavedAccount(
                username: username,
                hasSavedPassword: savePassword,
                avatar: avatar,
                nickname: nickname
            ))
        }

        if savePassword, let pwd = password {
            let obfuscated = obfuscate(pwd)
            UserDefaults.standard.set(obfuscated, forKey: passwordPrefix + username)
        } else if !savePassword {
            UserDefaults.standard.removeObject(forKey: passwordPrefix + username)
        }

        saveAccountList()
    }

    func updateAccountInfo(username: String, avatar: String, nickname: String) {
        if let idx = accounts.firstIndex(where: { $0.username == username }) {
            accounts[idx].avatar = avatar
            accounts[idx].nickname = nickname
        } else {
            accounts.append(SavedAccount(username: username, hasSavedPassword: false, avatar: avatar, nickname: nickname))
        }
        saveAccountList()
    }

    func removeAccount(_ account: SavedAccount) {
        UserDefaults.standard.removeObject(forKey: passwordPrefix + account.username)
        accounts.removeAll { $0.username == account.username }
        saveAccountList()
    }

    func getPassword(for username: String) -> String? {
        guard let data = UserDefaults.standard.string(forKey: passwordPrefix + username) else {
            return nil
        }
        return obfuscate(data)
    }

    private func obfuscate(_ text: String) -> String {
        let key: UInt8 = 0x5A
        return String(bytes: text.utf8.map { $0 ^ key }, encoding: .utf8) ?? text
    }
}
