import SwiftUI

// Centralized design tokens for ConsoleMac.
enum Theme {

    // MARK: Surfaces & text

    static var separator: Color { Color(nsColor: .separatorColor) }
    static var windowBackground: Color { Color(nsColor: .windowBackgroundColor) }
    static var controlBackground: Color { Color(nsColor: .controlBackgroundColor) }
    static var textBackground: Color { Color(nsColor: .textBackgroundColor) }
    static var secondaryText: Color { Color(nsColor: .secondaryLabelColor) }
    static var tertiaryText: Color { Color(nsColor: .tertiaryLabelColor) }
    static var subtleFill: Color { Color(nsColor: .quaternaryLabelColor).opacity(0.14) }
    static var hoverFill: Color { Color(nsColor: .quaternaryLabelColor).opacity(0.22) }
    static var elevatedFill: Color { Color(nsColor: .quaternaryLabelColor).opacity(0.30) }
    static var accent: Color { Color(nsColor: .controlAccentColor) }

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accent.opacity(0.78)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [Color.primary, Color.primary.opacity(0.72)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: Radii

    enum Radius {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let pill: CGFloat = 999
    }

    // MARK: Spacing

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
        static let xxl: CGFloat = 40
    }

    // MARK: Motion
    // Tuned for older Intel Macs: shorter durations, higher spring damping.

    enum Motion {
        // Snappy spring for taps and selections.
        static var snap: Animation { .spring(response: 0.28, dampingFraction: 0.82) }

        // Hover transitions — kept short to reduce GPU load.
        static var hover: Animation { .easeInOut(duration: 0.12) }

        // Slow ambient animation for idle backgrounds.
        static var ambient: Animation { .easeInOut(duration: 1.2) }

        // Gentle drift for decorative elements.
        static var drift: Animation { .easeInOut(duration: 3.5).repeatForever(autoreverses: true) }

        // Entrance animation for new messages.
        static var entrance: Animation { .spring(response: 0.35, dampingFraction: 0.75) }
    }
}
