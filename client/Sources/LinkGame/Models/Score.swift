import Foundation

struct ScoreRecord: Codable {
    let id: Int64
    let userID: Int64
    let username: String?
    let levelID: String
    let score: Int
    let timeSeconds: Int
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case username
        case levelID = "level_id"
        case score
        case timeSeconds = "time_seconds"
        case createdAt = "created_at"
    }
}

struct LeaderboardEntry: Codable, Identifiable {
    var id: String { "\(rank)-\(username)" }
    let rank: Int
    let username: String
    let avatar: String?
    let score: Int
    let timeSeconds: Int
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case rank, username, avatar, score
        case timeSeconds = "time_seconds"
        case createdAt = "created_at"
    }
}

struct LeaderboardResponse: Codable {
    let leaderboard: [LeaderboardEntry]
    let levelID: String?

    enum CodingKeys: String, CodingKey {
        case leaderboard
        case levelID = "level_id"
    }
}

struct ScoreSubmitResponse: Codable {
    let score: ScoreRecord?
    let error: String?
    let currency: Int64?
}

struct StatsResponse: Codable {
    let totalGames: Int
    let bestScore: Int
    let avgTime: Double

    enum CodingKeys: String, CodingKey {
        case totalGames = "total_games"
        case bestScore = "best_score"
        case avgTime = "avg_time"
    }
}

struct HistoryRecord: Codable, Identifiable {
    let id: Int64
    let levelID: String
    let score: Int
    let timeSeconds: Int
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case levelID = "level_id"
        case score
        case timeSeconds = "time_seconds"
        case createdAt = "created_at"
    }
}

struct HistoryResponse: Codable {
    let history: [HistoryRecord]
}

struct DailyUnlockResponse: Codable {
    let message: String?
    let currency: Int64?
    let error: String?
}

struct CurrencyLog: Codable, Identifiable {
    let id: Int64
    let userID: Int64
    let amount: Int64
    let reason: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, amount, reason
        case userID = "user_id"
        case createdAt = "created_at"
    }
}

struct CurrencyLogResponse: Codable {
    let logs: [CurrencyLog]?
}
