import SwiftUI

struct OnboardingView: View {
    @State private var apiKey = ""
    @State private var errorMessage: String?
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(AppTheme.accent)

            VStack(spacing: 8) {
                Text("Welcome to Nudge")
                    .font(.largeTitle.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Your voice-powered personal assistant for tasks and accountability.")
                    .font(.body)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Gemini API key")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                SecureField("Paste your key", text: $apiKey)
                    .padding()
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Link("Get a free key", destination: URL(string: "https://aistudio.google.com/apikey")!)
                    .font(.caption)
                    .foregroundStyle(AppTheme.accent)
            }
            .padding(.horizontal)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(AppTheme.overdue)
            }

            Button {
                Task { await finishOnboarding() }
            } label: {
                Text("Get started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.accent)
                    .foregroundStyle(AppTheme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal)

            Spacer()
        }
        .background(AppTheme.background)
    }

    private func finishOnboarding() async {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Please enter your Gemini API key."
            return
        }
        do {
            try KeychainHelper.saveAPIKey(trimmed)
            _ = await NotificationService.requestAuthorization()
            await NotificationService.rescheduleDailyNotifications()
            AppSettings.shared.hasCompletedOnboarding = true
            onComplete()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
