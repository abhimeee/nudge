import SwiftUI

struct MicButton: View {
    let isRecording: Bool
    let action: () -> Void

    @State private var pulse = false
    @State private var idleRing = false
    @State private var pressed = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
                pressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                pressed = false
            }
            action()
        } label: {
            ZStack {
                if !isRecording {
                    ForEach(0..<2, id: \.self) { ring in
                        Circle()
                            .stroke(AppTheme.accent.opacity(0.2 - Double(ring) * 0.06), lineWidth: 2)
                            .frame(width: 76 + CGFloat(ring) * 14, height: 76 + CGFloat(ring) * 14)
                            .scaleEffect(idleRing ? 1.08 : 1)
                            .opacity(idleRing ? 0.15 : 0.45)
                            .animation(
                                .easeInOut(duration: 2.2)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(ring) * 0.35),
                                value: idleRing
                            )
                    }
                }

                if isRecording {
                    Circle()
                        .stroke(AppTheme.accentSecondary.opacity(0.5), lineWidth: 3)
                        .frame(width: 88, height: 88)
                        .scaleEffect(pulse ? 1.25 : 1.0)
                        .opacity(pulse ? 0.1 : 0.55)
                        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
                }

                Circle()
                    .fill(AppTheme.accentGradient)
                    .frame(width: 68, height: 68)
                    .shadow(color: AppTheme.accent.opacity(0.35), radius: 16, y: 8)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.35), lineWidth: 1)
                    )

                Image(systemName: isRecording ? "waveform" : "mic.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.variableColor.iterative, isActive: isRecording)
            }
            .scaleEffect(pressed ? 0.9 : 1)
        }
        .buttonStyle(.plain)
        .onAppear {
            idleRing = true
            pulse = isRecording
        }
        .onChange(of: isRecording) { _, recording in
            pulse = recording
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: isRecording)
    }
}
