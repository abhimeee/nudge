import SwiftUI

struct SettingsView: View {
    @State private var apiKey = ""
    @State private var morningTime = Date()
    @State private var eveningTime = Date()
    @State private var overdueTime = Date()
    @State private var saveMessage: String?
    @State private var settings = AppSettings.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("Gemini API") {
                    SecureField("API key", text: $apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Button("Save API Key") {
                        saveAPIKey()
                    }
                    .foregroundStyle(AppTheme.accent)

                    if let saveMessage {
                        Text(saveMessage)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Link("Get a free key at Google AI Studio", destination: URL(string: "https://aistudio.google.com/apikey")!)
                        .font(.caption)
                }

                Section("Daily check-ins") {
                    DatePicker("Morning plan", selection: $morningTime, displayedComponents: .hourAndMinute)
                    DatePicker("Evening review", selection: $eveningTime, displayedComponents: .hourAndMinute)
                    DatePicker("Overdue nudge", selection: $overdueTime, displayedComponents: .hourAndMinute)
                }

                Section {
                    Button("Save schedule") {
                        saveSchedule()
                    }
                    .foregroundStyle(AppTheme.accent)
                } footer: {
                    Text("Local notifications only — no server required.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Settings")
            .onAppear {
                apiKey = KeychainHelper.loadAPIKey() ?? ""
                morningTime = dateFromComponents(settings.morningCheckInTime, defaultHour: 8)
                eveningTime = dateFromComponents(settings.eveningCheckInTime, defaultHour: 20)
                overdueTime = dateFromComponents(settings.overdueNudgeTime, defaultHour: 9)
            }
        }
    }

    private func saveAPIKey() {
        do {
            try KeychainHelper.saveAPIKey(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
            saveMessage = "API key saved securely."
        } catch {
            saveMessage = error.localizedDescription
        }
    }

    private func saveSchedule() {
        settings.morningCheckInTime = Calendar.current.dateComponents([.hour, .minute], from: morningTime)
        settings.eveningCheckInTime = Calendar.current.dateComponents([.hour, .minute], from: eveningTime)
        settings.overdueNudgeTime = Calendar.current.dateComponents([.hour, .minute], from: overdueTime)
        Task {
            await NotificationService.rescheduleDailyNotifications()
            saveMessage = "Schedule saved."
        }
    }

    private func dateFromComponents(_ components: DateComponents, defaultHour: Int) -> Date {
        var c = components
        c.hour = components.hour ?? defaultHour
        c.minute = components.minute ?? 0
        return Calendar.current.date(from: c) ?? Date()
    }
}
