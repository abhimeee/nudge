import SwiftUI
import SwiftData
import UserNotifications

@main
struct NudgeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var showOnboarding = !AppSettings.shared.hasCompletedOnboarding

    init() {
        AppTheme.configureUIKitAppearance()
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([TaskItem.self, CheckIn.self, UserStats.self, ConversationRecord.self, JournalEntry.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if showOnboarding {
                    OnboardingView {
                        showOnboarding = false
                    }
                } else {
                    MainTabView()
                }
            }
            .preferredColorScheme(.light)
        }
        .modelContainer(sharedModelContainer)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        NotificationCenter.default.post(
            name: .openVoiceCapture,
            object: nil,
            userInfo: userInfo as? [AnyHashable: Any]
        )
        completionHandler()
    }
}
