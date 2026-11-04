import SwiftUI
import WidgetKit

struct KernelEntry: TimelineEntry { let date: Date }
struct KernelTimeline: TimelineProvider {
    func placeholder(in context: Context) -> KernelEntry { KernelEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (KernelEntry) -> Void) { completion(KernelEntry(date: .now)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<KernelEntry>) -> Void) {
        completion(Timeline(entries: [KernelEntry(date: .now)], policy: .never))
    }
}

@main
struct KernelWidget: Widget {
    let kind = "KernelLauncher"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KernelTimeline()) { _ in
            VStack(alignment: .leading, spacing: 12) {
                HStack { Image(systemName: "circle.hexagongrid.fill"); Text("Kernel").font(.headline); Spacer() }
                Text("ひらめきを、\n会話に。").font(.title2.bold())
                Spacer(minLength: 0)
                Link(destination: URL(string: "kernel://new")!) { Label("新しいチャット", systemImage: "square.and.pencil").font(.subheadline) }
            }.containerBackground(for: .widget) { Color(uiColor: .secondarySystemBackground) }
                .widgetURL(URL(string: "kernel://new"))
        }.configurationDisplayName("Kernel · クイックチャット")
            .description("ワンタップで新しいチャットを開きます。会話内容はウィジェットに表示しません。")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}
