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
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    settingsCard(
                        title: "Gemini API",
                        icon: "key.fill",
                        tint: AppTheme.accent
                    ) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Connect voice parsing")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)

                            SecureField("API key", text: $apiKey)
                                .font(.body)
                                .padding(14)
                                .background(AppTheme.background)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .textContentType(.password)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)

                            Button(action: saveAPIKey) {
                                Text("Save API key")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(AppTheme.accentGradient)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)

                            if let saveMessage {
                                Text(saveMessage)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }

                            Link("Get a free key at Google AI Studio", destination: URL(string: "https://aistudio.google.com/apikey")!)
                                .font(.caption)
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                    .staggeredAppear(index: 0)

                    settingsCard(
                        title: "Daily check-ins",
                        icon: "bell.fill",
                        tint: AppTheme.accentSecondary
                    ) {
                        VStack(spacing: 4) {
                            scheduleRow(title: "Morning plan", selection: $morningTime)
                            Divider().overlay(AppTheme.divider)
                            scheduleRow(title: "Evening review", selection: $eveningTime)
                            Divider().overlay(AppTheme.divider)
                            scheduleRow(title: "Overdue nudge", selection: $overdueTime)
                        }

                        Button(action: saveSchedule) {
                            Text("Save schedule")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(AppTheme.accentGradient)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)

                        Text("Local notifications only. No server required.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .staggeredAppear(index: 1)
                }
                .padding(AppTheme.spacing)
                .padding(.bottom, 24)
            }
            .appScreenBackground()
            .navigationTitle("Settings")
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                apiKey = KeychainHelper.loadAPIKey() ?? ""
                morningTime = dateFromComponents(settings.morningCheckInTime, defaultHour: 8)
                eveningTime = dateFromComponents(settings.eveningCheckInTime, defaultHour: 20)
                overdueTime = dateFromComponents(settings.overdueNudgeTime, defaultHour: 9)
            }
        }
    }

    private func settingsCard<Content: View>(
        title: String,
        icon: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        LinearGradient(
                            colors: [tint, tint.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
            }

            content()
        }
        .cardStyle()
    }

    private func scheduleRow(title: String, selection: Binding<Date>) -> some View {
        HStack {
            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            DatePicker("", selection: selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .tint(AppTheme.accent)
        }
        .padding(.vertical, 6)
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
