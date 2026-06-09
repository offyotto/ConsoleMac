import AppKit
import SwiftUI

struct TerminalIconView: View {
    let size: CGFloat

    var body: some View {
        Image(nsImage: TerminalIconAsset.image)
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel("Terminal")
    }
}

@MainActor
private enum TerminalIconAsset {
    static let image: NSImage = {
        let filename = "terminal_24dp_1F1F1F_FILL0_wght400_GRAD0_opsz24"
        let loadedImage = ConsoleResources.url(forResource: filename, withExtension: "svg")
            .flatMap(NSImage.init(contentsOf:))

        let image = loadedImage
            ?? NSImage(systemSymbolName: "terminal", accessibilityDescription: "Terminal")
            ?? NSImage(size: NSSize(width: 24, height: 24))
        image.isTemplate = true
        return image
    }()
}
