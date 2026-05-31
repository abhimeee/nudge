import SwiftUI

struct StreakBadge: View {
    let streak: Int

    @State private var flameWiggle = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: streak > 0 ? "flame.fill" : "flame")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.accentGradient)
                .rotationEffect(.degrees(flameWiggle ? -8 : 8))
                .animation(
                    streak > 0
                        ? .easeInOut(duration: 0.45).repeatForever(autoreverses: true)
                        : .default,
                    value: flameWiggle
                )

            Text(streak == 0 ? "Light your streak today" : "\(streak)-day streak. Keep going!")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [
                    AppTheme.accent.opacity(0.14),
                    AppTheme.accentSecondary.opacity(0.1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(AppTheme.accent.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            if streak > 0 { flameWiggle = true }
        }
        .onChange(of: streak) { _, new in
            flameWiggle = new > 0
        }
    }
}
