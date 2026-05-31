import SwiftUI

struct MicButton: View {
    let isRecording: Bool
    let action: () -> Void

    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if isRecording {
                    Circle()
                        .stroke(AppTheme.accent.opacity(0.4), lineWidth: 3)
                        .frame(width: 80, height: 80)
                        .scaleEffect(pulse ? 1.2 : 1.0)
                        .opacity(pulse ? 0.2 : 0.6)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulse)
                }

                Circle()
                    .fill(isRecording ? AppTheme.accent : AppTheme.cardBackground)
                    .frame(width: 64, height: 64)
                    .shadow(color: AppTheme.accent.opacity(isRecording ? 0.4 : 0), radius: 12)

                Image(systemName: isRecording ? "waveform" : "mic.fill")
                    .font(.title2)
                    .foregroundStyle(isRecording ? AppTheme.background : AppTheme.accent)
            }
        }
        .buttonStyle(.plain)
        .onChange(of: isRecording) { _, recording in
            pulse = recording
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: isRecording)
    }
}
