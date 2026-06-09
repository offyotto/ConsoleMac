import Foundation

enum ConsoleResources {
    static func url(forResource name: String, withExtension extensionName: String, subdirectory: String? = nil) -> URL? {
        bundle.url(forResource: name, withExtension: extensionName, subdirectory: subdirectory)
            ?? bundle.url(forResource: name, withExtension: extensionName)
    }

    private static let bundleName = "ConsoleMac_ConsoleMac.bundle"

    private static let bundle: Bundle = {
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent(bundleName),
            Bundle.main.bundleURL.appendingPathComponent(bundleName)
        ].compactMap { $0 }

        for candidate in candidates {
            if let bundle = Bundle(url: candidate) {
                return bundle
            }
        }

        return Bundle.main
    }()
}
