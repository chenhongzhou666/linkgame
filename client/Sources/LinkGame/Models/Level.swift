import Foundation

struct DailyLevelResponse: Codable {
    let date: String
    let layoutData: String

    enum CodingKeys: String, CodingKey {
        case date
        case layoutData = "layout_data"
    }
}
