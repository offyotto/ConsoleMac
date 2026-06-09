import AppKit
import SwiftUI

struct ProviderLogoView: View {
    let provider: ModelProvider
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Image(nsImage: ProviderLogoCache.image(for: provider))
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(width: width, height: height, alignment: .leading)
            .foregroundStyle(.primary)
            .accessibilityLabel(provider.displayName)
    }
}

@MainActor
private enum ProviderLogoCache {
    static func image(for provider: ModelProvider) -> NSImage {
        if let cachedImage = images[provider.logoFilename] {
            return cachedImage
        }

        let loadedImage = ConsoleResources.url(
            forResource: provider.logoFilename,
            withExtension: "svg",
            subdirectory: "ProviderLogos"
        )
        .flatMap(NSImage.init(contentsOf:))

        let image = loadedImage
            ?? NSImage(systemSymbolName: "circle", accessibilityDescription: provider.displayName)
            ?? NSImage(size: NSSize(width: 120, height: 40))
        image.isTemplate = true
        images[provider.logoFilename] = image
        return image
    }

    private static var images: [String: NSImage] = [:]
}
