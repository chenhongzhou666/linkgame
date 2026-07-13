import Foundation

enum APIClient {
    static let baseURL = "http://localhost:9090"

    static var token: String?

    static func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        var components = URLComponents(string: "\(baseURL)\(path)")!
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResp = response as? HTTPURLResponse, httpResp.statusCode >= 400 {
            if let errJson = try? JSONDecoder().decode([String: String].self, from: data),
               let msg = errJson["error"] {
                throw NSError(domain: "API", code: httpResp.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
            }
            throw NSError(domain: "API", code: httpResp.statusCode, userInfo: [NSLocalizedDescriptionKey: "请求失败 (\(httpResp.statusCode))"])
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    static func post<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        var request = URLRequest(url: URL(string: "\(baseURL)\(path)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResp = response as? HTTPURLResponse, httpResp.statusCode >= 400 {
            if let errJson = try? JSONDecoder().decode([String: String].self, from: data),
               let msg = errJson["error"] {
                throw NSError(domain: "API", code: httpResp.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
            }
            throw NSError(domain: "API", code: httpResp.statusCode, userInfo: [NSLocalizedDescriptionKey: "请求失败 (\(httpResp.statusCode))"])
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    static func submitScore(levelID: String, score: Int, timeSeconds: Int) async throws -> ScoreSubmitResponse {
        return try await post("/api/score", body: [
            "level_id": levelID,
            "score": score,
            "time_seconds": timeSeconds
        ])
    }

    static func getDailyLevel() async throws -> DailyLevelResponse {
        return try await get("/api/daily")
    }

    static func getLeaderboard(levelID: String? = nil, limit: Int = 100) async throws -> LeaderboardResponse {
        var query: [String: String] = ["limit": String(limit)]
        if let lid = levelID, !lid.isEmpty {
            query["level_id"] = lid
        }
        return try await get("/api/leaderboard", query: query)
    }

    static func getMyStats(levelID: String? = nil) async throws -> StatsResponse {
        var query: [String: String] = [:]
        if let lid = levelID, !lid.isEmpty { query["level_id"] = lid }
        return try await get("/api/my/stats", query: query)
    }

    static func getMyHistory(limit: Int = 100, levelID: String? = nil) async throws -> HistoryResponse {
        var query = ["limit": String(limit)]
        if let lid = levelID, !lid.isEmpty { query["level_id"] = lid }
        return try await get("/api/my/history", query: query)
    }

    static func forgotPassword(email: String) async throws -> [String: String] {
        return try await post("/api/forgot-password", body: ["email": email])
    }

    static func resetPassword(email: String, code: String, newPassword: String) async throws -> [String: String] {
        return try await post("/api/reset-password", body: [
            "email": email,
            "code": code,
            "new_password": newPassword
        ])
    }

    static func bindEmail(_ email: String) async throws -> [String: String] {
        return try await post("/api/bind-email", body: ["email": email])
    }

    static func updateNickname(_ nickname: String) async throws -> [String: String] {
        return try await post("/api/me/nickname", body: ["nickname": nickname])
    }

    static func unlockDaily() async throws -> DailyUnlockResponse {
        return try await post("/api/me/daily-unlock", body: [:])
    }

    static func getCurrencyLogs() async throws -> CurrencyLogResponse {
        return try await get("/api/me/currency-logs")
    }

    static func uploadAvatarImage(_ imageData: Data) async throws -> [String: String] {
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "\(baseURL)/api/me/avatar/upload")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"avatar.png\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([String: String].self, from: data)
    }

}
