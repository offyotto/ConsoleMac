import SwiftUI

enum Typography {
    enum InterfaceStyle {
        case regular
        case medium
        case semibold
        case bold
    }

    enum ProseStyle {
        case regular
        case italic
        case bold
    }

    static func interface(_ size: CGFloat, _ style: InterfaceStyle = .regular) -> Font {
        .system(size: size, weight: weight(for: style), design: .default)
    }

    static func prose(_ size: CGFloat, _ style: ProseStyle = .regular) -> Font {
        .system(size: size, weight: proseWeight(for: style), design: .default)
    }

    static func code(_ size: CGFloat) -> Font {
        Font.custom("Menlo-Regular", size: size)
    }

    private static func weight(for style: InterfaceStyle) -> Font.Weight {
        switch style {
        case .regular:
            return .regular
        case .medium:
            return .medium
        case .semibold:
            return .semibold
        case .bold:
            return .bold
        }
    }

    private static func proseWeight(for style: ProseStyle) -> Font.Weight {
        switch style {
        case .regular:
            return .regular
        case .italic:
            return .regular
        case .bold:
            return .semibold
        }
    }
}
