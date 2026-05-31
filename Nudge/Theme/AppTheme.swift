import SwiftUI
import UIKit

enum AppTheme {
    // Soft light palette — lavender cream, violet accent, playful pastels
    static let background = Color(red: 0.97, green: 0.96, blue: 0.99)
    static let cardBackground = Color.white
    static let accent = Color(red: 0.55, green: 0.45, blue: 0.98)
    static let accentSecondary = Color(red: 1.0, green: 0.45, blue: 0.65)
    static let accentMuted = Color(red: 0.55, green: 0.45, blue: 0.98).opacity(0.12)
    static let textPrimary = Color(red: 0.12, green: 0.11, blue: 0.22)
    static let textSecondary = Color(red: 0.45, green: 0.44, blue: 0.55)
    static let overdue = Color(red: 0.95, green: 0.38, blue: 0.48)
    static let success = Color(red: 0.22, green: 0.78, blue: 0.62)
    static let sky = Color(red: 0.35, green: 0.68, blue: 0.98)
    static let peach = Color(red: 1.0, green: 0.72, blue: 0.55)
    static let divider = Color(red: 0.88, green: 0.86, blue: 0.94)

    static let cornerRadius: CGFloat = 20
    static let spacing: CGFloat = 16
    static let cardShadow = Color(red: 0.45, green: 0.35, blue: 0.75).opacity(0.08)

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accentSecondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.55, green: 0.45, blue: 0.98),
                Color(red: 0.72, green: 0.52, blue: 0.98),
                Color(red: 1.0, green: 0.55, blue: 0.72)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static func configureUIKitAppearance() {
        let backgroundUIColor = UIColor(background)

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(cardBackground)
        tabAppearance.shadowColor = UIColor(cardShadow)
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().tintColor = UIColor(accent)
        UITabBar.appearance().unselectedItemTintColor = UIColor(textSecondary)

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.backgroundColor = .clear
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor(textPrimary)]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(textPrimary)]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = UIColor(accent)

        UITableView.appearance().backgroundColor = .clear
        UIScrollView.appearance().backgroundColor = backgroundUIColor
    }
}

// MARK: - Card & background

extension View {
    func cardStyle(padding: CGFloat = AppTheme.spacing) -> some View {
        self
            .padding(padding)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
            .shadow(color: AppTheme.cardShadow, radius: 12, y: 4)
    }

    func softCardStyle() -> some View {
        self
            .padding(14)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: AppTheme.cardShadow, radius: 8, y: 3)
    }

    func appScreenBackground() -> some View {
        ZStack {
            AnimatedMeshBackground()
            self
        }
        .background(AppTheme.background)
    }
}

// MARK: - Floating mesh blobs

struct AnimatedMeshBackground: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                AppTheme.accent.opacity(0.22),
                                AppTheme.accent.opacity(0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: geo.size.width * 0.45
                        )
                    )
                    .frame(width: geo.size.width * 0.9, height: geo.size.width * 0.9)
                    .offset(
                        x: -geo.size.width * 0.2 + sin(phase) * 24,
                        y: -geo.size.height * 0.15 + cos(phase * 0.7) * 18
                    )

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                AppTheme.accentSecondary.opacity(0.18),
                                AppTheme.accentSecondary.opacity(0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: geo.size.width * 0.4
                        )
                    )
                    .frame(width: geo.size.width * 0.75, height: geo.size.width * 0.75)
                    .offset(
                        x: geo.size.width * 0.35 + cos(phase * 0.9) * 20,
                        y: geo.size.height * 0.05 + sin(phase * 1.1) * 22
                    )

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                AppTheme.peach.opacity(0.2),
                                AppTheme.peach.opacity(0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: geo.size.width * 0.35
                        )
                    )
                    .frame(width: geo.size.width * 0.6, height: geo.size.width * 0.6)
                    .offset(
                        x: geo.size.width * 0.1 + sin(phase * 1.3) * 16,
                        y: geo.size.height * 0.28 + cos(phase) * 14
                    )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - Motion modifiers

struct StaggeredAppear: ViewModifier {
    let index: Int
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 18)
            .scaleEffect(visible ? 1 : 0.96)
            .onAppear {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.78).delay(Double(index) * 0.07)) {
                    visible = true
                }
            }
    }
}

struct BounceScale: ViewModifier {
    let trigger: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(trigger ? 1.08 : 1)
            .animation(.spring(response: 0.35, dampingFraction: 0.55), value: trigger)
    }
}

extension View {
    func staggeredAppear(index: Int) -> some View {
        modifier(StaggeredAppear(index: index))
    }

    func bounceScale(trigger: Bool) -> some View {
        modifier(BounceScale(trigger: trigger))
    }
}
