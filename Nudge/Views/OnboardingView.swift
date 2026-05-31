import SwiftUI

struct OnboardingView: View {
    @State private var apiKey = ""
    @State private var errorMessage: String?
    @State private var heroPulse = false
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppTheme.accentMuted)
                    .frame(width: 120, height: 120)
                    .scaleEffect(heroPulse ? 1.08 : 0.95)

                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(AppTheme.heroGradient)
                    .offset(y: heroPulse ? -3 : 3)
            }

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
                Text("Gemini API key (optional)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.textSecondary)
                Text("Voice tasks work without a key. Add one later in Settings for smarter parsing.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                SecureField("Paste your key", text: $apiKey)
                    .padding()
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: AppTheme.cardShadow, radius: 8, y: 3)
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
                    .background(AppTheme.accentGradient)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: AppTheme.accent.opacity(0.3), radius: 12, y: 6)
            }
            .padding(.horizontal)

            Spacer()
        }
        .appScreenBackground()
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                heroPulse = true
            }
        }
    }

    private func finishOnboarding() async {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if !trimmed.isEmpty {
                try KeychainHelper.saveAPIKey(trimmed)
            }
            _ = await NotificationService.requestAuthorization()
            await NotificationService.rescheduleDailyNotifications()
            AppSettings.shared.hasCompletedOnboarding = true
            onComplete()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
