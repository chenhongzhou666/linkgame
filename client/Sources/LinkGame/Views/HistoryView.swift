import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var auth: AuthState
    @Environment(\.dismiss) private var dismiss
    @State private var records: [HistoryRecord] = []
    @State private var isLoading = true
    @State private var errorMsg: String?
    var levelID: String? = nil

    private var title: String {
        switch levelID {
        case "classic": return "经典模式 · 对局记录"
        case "timed":   return "限时模式 · 对局记录"
        case "step":    return "步步为营 · 对局记录"
        default:        return "对局记录"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.title2.bold())
                Spacer()
                Button("关闭") { dismiss() }
                    .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if let error = errorMsg {
                Spacer()
                Text(error).foregroundStyle(.secondary)
                Spacer()
            } else if records.isEmpty {
                Spacer()
                Text("暂无对局记录").foregroundStyle(.secondary)
                Spacer()
            } else {
                List(records) { record in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(modeLabel(record.levelID))
                                .font(.subheadline)
                            Text(formattedDate(record.createdAt))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("\(record.score) 分")
                            .fontWeight(.medium)

                        Text(timeString(record.timeSeconds))
                            .foregroundStyle(.secondary)
                            .frame(width: 48, alignment: .trailing)
                    }
                    .padding(.vertical, 2)
                }
            }

            Text("最多保存 100 条记录")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.vertical, 6)
        }
        .frame(minWidth: 420, minHeight: 360)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        APIClient.token = auth.token
        do {
            let resp: HistoryResponse = try await APIClient.getMyHistory(limit: 100, levelID: levelID)
            records = resp.history
        } catch {
            errorMsg = error.localizedDescription
        }
        isLoading = false
    }

    private func modeLabel(_ levelID: String) -> String {
        if levelID.hasPrefix("daily-") { return "每日挑战" }
        switch levelID {
        case "classic": return "经典模式"
        case "timed":   return "限时模式"
        case "step":    return "步步为营"
        default:        return "经典模式"
        }
    }

    private func formattedDate(_ raw: String) -> String {
        let serverFmt = DateFormatter()
        serverFmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        serverFmt.timeZone = TimeZone(identifier: "Asia/Shanghai")
        if let date = serverFmt.date(from: raw) {
            let display = DateFormatter()
            display.dateFormat = "MM-dd HH:mm"
            return display.string(from: date)
        }
        return String(raw.prefix(16))
    }

    private func timeString(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
