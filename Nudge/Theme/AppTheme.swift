import SwiftUI

enum AppTheme {
    static let background = Color(red: 0.04, green: 0.04, blue: 0.043)
    static let cardBackground = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let accent = Color(red: 0.96, green: 0.65, blue: 0.14)
    static let accentMuted = Color(red: 0.96, green: 0.65, blue: 0.14).opacity(0.2)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.55)
    static let overdue = Color(red: 0.95, green: 0.35, blue: 0.35)
    static let success = Color(red: 0.35, green: 0.82, blue: 0.55)

    static let cornerRadius: CGFloat = 16
    static let spacing: CGFloat = 16
}

extension View {
    func cardStyle() -> some View {
        self
            .padding(AppTheme.spacing)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
    }
}
