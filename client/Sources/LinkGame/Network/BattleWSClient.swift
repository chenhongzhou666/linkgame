import Foundation

// MARK: - Types

struct MatchFoundInfo: Codable {
    var opponentName: String
    var opponentAvatar: String
    var board: [[Int]]
    var hp: Int
}

struct HitInfo: Codable {
    var attacker: String
    var myHP: Int
    var opponentHP: Int
}

struct GameOverInfo: Codable {
    var result: String
    var myHP: Int
    var opponentHP: Int
    var trophies: Int
}

struct OnlinePlayer: Codable, Identifiable {
    var userId: Int64
    var username: String
    var trophies: Int
    var id: Int64 { userId }
}

struct InviteReceived: Codable {
    var fromUserId: Int64
    var fromUsername: String
    var fromTrophies: Int
}

enum BattleWSState {
    case disconnected, connecting, lobby
    case playing(MatchFoundInfo)
    case finished(GameOverInfo)
    case kicked(String)
    var label: String { "\(self)" }
}

// MARK: - BattleClient (HTTP polling)

@MainActor
class BattleWSClient: ObservableObject {
    @Published var state: BattleWSState = .disconnected
    @Published var players: [OnlinePlayer] = []
    @Published var lastHit: HitInfo?
    @Published var inviteReceived: InviteReceived?
    @Published var inviteError: String?
    @Published var inviteDeclinedBy: String?
    @Published var debugInfo: String = ""

    private var pollTimer: Timer?
    private var playerListTimer: Timer?

    func connect(token: String) {
        APIClient.token = token
        state = .connecting
        debugInfo = "正在加入大厅..."

        Task {
            do {
                let _: [String: String] = try await APIClient.post("/api/battle/join", body: [:])
                state = .lobby
                debugInfo = "已加入大厅"
                startPolling()
                startPlayerListPolling()
            } catch {
                debugInfo = "加入失败: \(error.localizedDescription)"
                state = .disconnected
                // 2秒后重试
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    self?.connect(token: token)
                }
            }
        }
    }

    func disconnect() {
        pollTimer?.invalidate(); pollTimer = nil
        playerListTimer?.invalidate(); playerListTimer = nil
        Task {
            let _: [String: String]? = try? await APIClient.post("/api/battle/leave", body: [:])
        }
        state = .disconnected
    }

    // MARK: - Polling

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.pollStatus()
            }
        }
        // 立刻 poll 一次
        Task { await pollStatus() }
    }

    private func startPlayerListPolling() {
        playerListTimer?.invalidate()
        playerListTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.pollPlayerList()
            }
        }
        Task { await pollPlayerList() }
    }

    private func pollStatus() async {
        do {
            let resp: [String: Any] = try await genericGet("/api/battle/status", query: [:])
            guard let status = resp["status"] as? String else { return }

            switch status {
            case "lobby":
                break
            case "playing":
                let board = resp["board"] as? [[Int]]
                let hp = resp["hp"] as? Int ?? 100
                let opp = resp["opponent_name"] as? String ?? "对手"
                // board comes from events... handle differently
                if let events = resp["events"] as? [[String: Any]] {
                    for ev in events {
                        if let et = ev["type"] as? String, et == "game_start",
                           let data = ev["data"] as? [String: Any] {
                            let b = data["board"] as? [[Int]] ?? []
                            let h = data["hp"] as? Int ?? 100
                            let on = data["opponent_name"] as? String ?? "对手"
                            state = .playing(MatchFoundInfo(opponentName: on, opponentAvatar: "", board: b, hp: h))
                            return
                        }
                    }
                } else if let b = board, let h = hp as? Int {
                    state = .playing(MatchFoundInfo(opponentName: opp, opponentAvatar: "", board: b, hp: h))
                }

            case "game_over":
                let outcome = resp["outcome"] as? String ?? "lose"
                let myHp = resp["my_hp"] as? Int ?? 0
                let oppHp = resp["opponent_hp"] as? Int ?? 0
                let trophies = resp["trophies"] as? Int ?? -1
                state = .finished(GameOverInfo(result: outcome, myHP: myHp, opponentHP: oppHp, trophies: trophies))

            default:
                break
            }

            // 处理事件
            if let events = resp["events"] as? [[String: Any]] {
                for ev in events {
                    handleEvent(ev)
                }
            }
        } catch {
            print("Battle poll error: \(error)")
        }
    }

    private func pollPlayerList() async {
        do {
            let resp: [String: Any] = try await genericGet("/api/battle/online", query: [:])
            if let arr = resp["players"] as? [[String: Any]] {
                var list: [OnlinePlayer] = []
                for item in arr {
                    if let uid = item["user_id"] as? Int64,
                       let name = item["username"] as? String {
                        let trophies = item["trophies"] as? Int ?? 0
                        list.append(OnlinePlayer(userId: uid, username: name, trophies: trophies))
                    }
                }
                players = list
            }
        } catch {
            // 静默失败
        }
    }

    private func handleEvent(_ ev: [String: Any]) {
        guard let type = ev["type"] as? String else { return }
        let data = ev["data"] as? [String: Any]

        switch type {
        case "invite_received":
            if let d = data {
                inviteReceived = InviteReceived(
                    fromUserId: d["from_user_id"] as? Int64 ?? 0,
                    fromUsername: d["from_username"] as? String ?? "",
                    fromTrophies: d["from_trophies"] as? Int ?? 0
                )
            }
        case "invite_declined":
            inviteDeclinedBy = data?["from_username"] as? String
        case "hit":
            if let d = data {
                lastHit = HitInfo(
                    attacker: "opponent",
                    myHP: d["my_hp"] as? Int ?? 0,
                    opponentHP: d["opponent_hp"] as? Int ?? 0
                )
            }
        case "game_start":
            if let d = data {
                state = .playing(MatchFoundInfo(
                    opponentName: d["opponent_name"] as? String ?? "对手",
                    opponentAvatar: "",
                    board: d["board"] as? [[Int]] ?? [],
                    hp: d["hp"] as? Int ?? 100
                ))
            }
        case "opponent_left":
            state = .disconnected
        default:
            break
        }
    }

    // MARK: - Send actions

    func sendInvite(to userId: Int64) {
        Task {
            do {
                let _: [String: String] = try await APIClient.post("/api/battle/invite", body: ["to_user_id": userId])
            } catch {
                inviteError = error.localizedDescription
            }
        }
    }

    func respondToInvite(accept: Bool) {
        guard let invite = inviteReceived else { return }
        inviteReceived = nil
        Task {
            do {
                let _: [String: String] = try await APIClient.post("/api/battle/respond", body: [
                    "from_user_id": invite.fromUserId,
                    "accept": accept
                ])
            } catch {
                print("respond error: \(error)")
            }
        }
    }

    func sendMatch(row1: Int, col1: Int, row2: Int, col2: Int) {
        Task {
            do {
                let resp = try await postDict("/api/battle/match", body: [
                    "row1": row1, "col1": col1,
                    "row2": row2, "col2": col2
                ])
                guard let valid = resp["valid"] as? Bool, valid else { return }
                let myHp = resp["my_hp"] as? Int ?? 0
                let oppHp = resp["opponent_hp"] as? Int ?? 0
                lastHit = HitInfo(attacker: "me", myHP: myHp, opponentHP: oppHp)
            } catch {
                print("match error: \(error)")
            }
        }
    }

    // MARK: - Generic HTTP

    private func postDict(_ path: String, body: [String: Any]) async throws -> [String: Any] {
        var req = URLRequest(url: URL(string: "\(APIClient.baseURL)\(path)")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = APIClient.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: req)
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json
        }
        throw NSError(domain: "battle", code: -1)
    }

    private func genericGet(_ path: String, query: [String: String]) async throws -> [String: Any] {
        var components = URLComponents(string: "\(APIClient.baseURL)\(path)")!
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        var req = URLRequest(url: components.url!)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = APIClient.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, _) = try await URLSession.shared.data(for: req)
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json
        }
        throw NSError(domain: "battle", code: -1, userInfo: [NSLocalizedDescriptionKey: "invalid response"])
    }
}
