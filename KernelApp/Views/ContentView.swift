import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var chatVM: ChatViewModel
    @EnvironmentObject private var jitService: JITService
    @EnvironmentObject private var settings: AppSettings

    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
        } detail: {
            if chatVM.currentConversation != nil {
                ChatView()
            } else {
                emptyState
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            jitService.checkJITStatus()
            if jitService.status != .enabled {
                jitService.enableJIT()
            }
        }
    }

    private var emptyState: some View {
        ZStack {
            ThemeEngine.backgroundColor(for: settings.theme)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "message.circle")
                    .font(.system(size: 60))
                    .foregroundColor(settings.accentColor.color.opacity(0.5))

                Text("会話を選択してください")
                    .font(.title2)
                    .foregroundColor(ThemeEngine.textColor(for: settings.theme))

                Text("サイドバーから新しい会話を開始するか、既存の会話を選択してください")
                    .font(.body)
                    .foregroundColor(ThemeEngine.secondaryTextColor(for: settings.theme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
}
