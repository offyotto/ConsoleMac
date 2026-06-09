import SwiftUI

struct ProviderLogoView: View {
    let provider: ModelProvider
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(provider.badgeColor.opacity(0.16))

            Text(provider.badgeText)
                .font(Typography.interface(15, .bold))
                .foregroundStyle(provider.badgeColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(width: width, height: height)
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(provider.badgeColor.opacity(0.30), lineWidth: 1)
        }
        .accessibilityLabel(provider.displayName)
    }
}

private extension ModelProvider {
    var badgeText: String {
        switch self {
        case .qwen:
            return "Q"
        case .deepSeek:
            return "DS"
        case .meta:
            return "∞"
        case .mistral:
            return "MI"
        }
    }

    var badgeColor: Color {
        switch self {
        case .qwen:
            return Color(red: 0.44, green: 0.67, blue: 1.0)
        case .deepSeek:
            return Color(red: 0.54, green: 0.78, blue: 0.95)
        case .meta:
            return Color(red: 0.50, green: 0.61, blue: 1.0)
        case .mistral:
            return Color(red: 1.0, green: 0.68, blue: 0.30)
        }
    }
}
