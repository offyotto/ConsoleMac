import SwiftUI

/// Centralized design tokens for ConsoleMac.
///
/// `Theme` exposes semantic colors that adapt to light/dark mode, along with
/// reusable layout, motion, and elevation tokens consumed across the app.
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

    /// Soft accent gradient for highlights, send button, etc.
    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accent.opacity(0.78)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Brand mark gradient used on the terminal icon and brand circle.
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

    enum Motion {
        /// Snappy spring for taps and selections.
        static var snap: Animation { .spring(response: 0.32, dampingFraction: 0.78) }
        /// Smooth ease used for hover transitions.
        static var hover: Animation { .easeInOut(duration: 0.16) }
        /// Slow ambient animation for backgrounds.
        static var ambient: Animation { .easeInOut(duration: 1.6) }
        /// Drift used on the home greeting.
        static var drift: Animation { .easeInOut(duration: 4.5).repeatForever(autoreverses: true) }
    }
}
