import AppKit
import SwiftUI

enum ConsoleSymbolAsset {
    case temporaryChat
    case models
    case retention

    var accessibilityLabel: String {
        switch self {
        case .temporaryChat:
            return "Temporary Chat"
        case .models:
            return "Models"
        case .retention:
            return "Retention"
        }
    }

    fileprivate var filename: String {
        switch self {
        case .temporaryChat:
            return "chat_dashed_24dp_E3E3E3_FILL0_wght400_GRAD0_opsz24"
        case .models:
            return "robot_2_24dp_E3E3E3_FILL0_wght400_GRAD0_opsz24"
        case .retention:
            return "hourglass_24dp_E3E3E3_FILL0_wght400_GRAD0_opsz24"
        }
    }

    fileprivate var fallbackSymbolName: String {
        switch self {
        case .temporaryChat:
            return "bubble.left"
        case .models:
            return "cpu"
        case .retention:
            return "hourglass"
        }
    }
}

struct ConsoleSymbolView: View {
    let asset: ConsoleSymbolAsset
    let size: CGFloat

    var body: some View {
        Image(nsImage: ConsoleSymbolCache.image(for: asset))
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel(asset.accessibilityLabel)
    }
}

@MainActor
private enum ConsoleSymbolCache {
    static func image(for asset: ConsoleSymbolAsset) -> NSImage {
        if let cachedImage = images[asset.filename] {
            return cachedImage
        }

        let loadedImage = ConsoleResources.url(forResource: asset.filename, withExtension: "svg")
            .flatMap(NSImage.init(contentsOf:))

        let image = loadedImage
            ?? NSImage(systemSymbolName: asset.fallbackSymbolName, accessibilityDescription: asset.accessibilityLabel)
            ?? NSImage(size: NSSize(width: 24, height: 24))
        image.isTemplate = true
        images[asset.filename] = image
        return image
    }

    private static var images: [String: NSImage] = [:]
}
