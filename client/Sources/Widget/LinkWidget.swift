import WidgetKit
import SwiftUI

struct WidgetEntry: TimelineEntry {
    let date: Date
    let skin: WidgetSkin
    let currencyBalance: Int
    let ownedSkinCount: Int
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), skin: .defaultSkin, currencyBalance: 0, ownedSkinCount: 1)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        let entry = WidgetEntry(
            date: Date(),
            skin: WidgetDataProvider.activeSkin,
            currencyBalance: WidgetDataProvider.currencyBalance,
            ownedSkinCount: WidgetDataProvider.purchasedSkinIDs.count
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        let entry = WidgetEntry(
            date: Date(),
            skin: WidgetDataProvider.activeSkin,
            currencyBalance: WidgetDataProvider.currencyBalance,
            ownedSkinCount: WidgetDataProvider.purchasedSkinIDs.count
        )
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct LinkWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: WidgetEntry

    var body: some View {
        let skin = entry.skin
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                Image(systemName: skin.badgeIcon)
                    .font(.system(size: 10, weight: .bold))
                Text("泓泓看")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundColor(skin.fgColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 6).fill(skin.accent))

            Spacer(minLength: 2)

            VStack(spacing: 2) {
                Text(skin.name)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(skin.fgColor)

                HStack(spacing: 2) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 8))
                    Text("\(entry.currencyBalance)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                }
                .foregroundColor(skin.accent)

                Text("\(entry.ownedSkinCount) 个挂件")
                    .font(.system(size: 7))
                    .foregroundColor(skin.fgColor.opacity(0.6))
            }

            Spacer(minLength: 2)

            HStack(spacing: 1) {
                ForEach(0..<12, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(i % 2 == 0 ? skin.accent : skin.fgColor.opacity(0.3))
                        .frame(width: 6, height: 2)
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 12).fill(skin.bgColor))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(skin.accent.opacity(0.3), lineWidth: 1)
        )
    }
}

struct LinkWidget: Widget {
    let kind = "com.chenhongzhou.linkgame.widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LinkWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("泓泓看挂件")
        .description("桌面小拉链，展示你的挂件收藏和金币")
        .supportedFamilies([.systemSmall])
    }
}
