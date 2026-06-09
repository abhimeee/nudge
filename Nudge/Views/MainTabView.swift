import SwiftUI

struct MainTabView: View {
    @State private var showVoiceSheet = false
    @State private var checkInType: CheckInType?
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(showVoiceSheet: $showVoiceSheet, checkInType: $checkInType)
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
                .tag(0)

            JournalView()
                .tabItem { Label("Journal", systemImage: "book.closed.fill") }
                .tag(1)

            ConversationLogView()
                .tabItem { Label("Log", systemImage: "waveform.circle.fill") }
                .tag(2)

            InboxView()
                .tabItem { Label("Inbox", systemImage: "tray.fill") }
                .tag(3)

            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
                .tag(4)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(5)
        }
        .tint(AppTheme.accent)
        .toolbarBackground(AppTheme.cardBackground, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .sheet(isPresented: $showVoiceSheet) {
            VoiceCaptureSheet(checkInType: checkInType)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openVoiceCapture)) { notification in
            if let raw = notification.userInfo?["checkIn"] as? String,
               let type = CheckInType(rawValue: raw) {
                checkInType = type
            } else {
                checkInType = nil
            }
            showVoiceSheet = true
        }
    }
}

extension Notification.Name {
    static let openVoiceCapture = Notification.Name("openVoiceCapture")
}
