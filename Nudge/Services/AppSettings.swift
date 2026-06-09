import Foundation

@Observable
final class AppSettings {
    static let shared = AppSettings()

    private enum Keys {
        static let morningHour = "morningCheckInHour"
        static let morningMinute = "morningCheckInMinute"
        static let eveningHour = "eveningCheckInHour"
        static let eveningMinute = "eveningCheckInMinute"
        static let overdueHour = "overdueNudgeHour"
        static let overdueMinute = "overdueNudgeMinute"
        static let onboardingComplete = "onboardingComplete"
        static let useLLM = "useLLM"
        static let useGeminiForConversations = "useGeminiForConversations"
    }

    private let defaults = UserDefaults.standard

    var morningCheckInTime: DateComponents {
        get { timeComponents(hourKey: Keys.morningHour, minuteKey: Keys.morningMinute, defaultHour: 8) }
        set {
            defaults.set(newValue.hour ?? 8, forKey: Keys.morningHour)
            defaults.set(newValue.minute ?? 0, forKey: Keys.morningMinute)
        }
    }

    var eveningCheckInTime: DateComponents {
        get { timeComponents(hourKey: Keys.eveningHour, minuteKey: Keys.eveningMinute, defaultHour: 20) }
        set {
            defaults.set(newValue.hour ?? 20, forKey: Keys.eveningHour)
            defaults.set(newValue.minute ?? 0, forKey: Keys.eveningMinute)
        }
    }

    var overdueNudgeTime: DateComponents {
        get { timeComponents(hourKey: Keys.overdueHour, minuteKey: Keys.overdueMinute, defaultHour: 9) }
        set {
            defaults.set(newValue.hour ?? 9, forKey: Keys.overdueHour)
            defaults.set(newValue.minute ?? 0, forKey: Keys.overdueMinute)
        }
    }

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Keys.onboardingComplete) }
        set { defaults.set(newValue, forKey: Keys.onboardingComplete) }
    }

    var hasAPIKey: Bool {
        KeychainHelper.loadAPIKey()?.isEmpty == false
    }

    /// When false, voice capture creates tasks from STT text only (no Gemini).
    var useLLM: Bool {
        get {
            guard defaults.object(forKey: Keys.useLLM) != nil else { return false }
            return defaults.bool(forKey: Keys.useLLM)
        }
        set { defaults.set(newValue, forKey: Keys.useLLM) }
    }

    /// When true (default if API key exists), conversation logs use Gemini audio transcription.
    var useGeminiForConversations: Bool {
        get {
            if defaults.object(forKey: Keys.useGeminiForConversations) == nil {
                return hasAPIKey
            }
            return defaults.bool(forKey: Keys.useGeminiForConversations)
        }
        set { defaults.set(newValue, forKey: Keys.useGeminiForConversations) }
    }

    private func timeComponents(hourKey: String, minuteKey: String, defaultHour: Int) -> DateComponents {
        var components = DateComponents()
        if defaults.object(forKey: hourKey) == nil {
            components.hour = defaultHour
            components.minute = 0
        } else {
            components.hour = defaults.integer(forKey: hourKey)
            components.minute = defaults.integer(forKey: minuteKey)
        }
        return components
    }
}
