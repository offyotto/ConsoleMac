import SwiftUI

enum Theme {
    static var separator: Color { Color(nsColor: .separatorColor) }
    static var windowBackground: Color { Color(nsColor: .windowBackgroundColor) }
    static var controlBackground: Color { Color(nsColor: .controlBackgroundColor) }
    static var textBackground: Color { Color(nsColor: .textBackgroundColor) }
    static var secondaryText: Color { Color(nsColor: .secondaryLabelColor) }
    static var tertiaryText: Color { Color(nsColor: .tertiaryLabelColor) }
    static var subtleFill: Color { Color(nsColor: .quaternaryLabelColor).opacity(0.14) }
    static var accent: Color { Color(nsColor: .controlAccentColor) }
}
