import Foundation

enum FileSearchService {
    static func context(
        for conversation: Conversation,
        preferences: AppPreferences
    ) -> String {
        guard let query = conversation.messages.last(where: { $0.role == .user })?.plainText else {
            return ""
        }

        return context(for: query, preferences: preferences)
    }

    static func context(
        for query: String,
        preferences: AppPreferences
    ) -> String {
        let resources = searchResources(for: preferences)

        guard preferences.agentSearchEnabled,
              resources.isEmpty == false else {
            return ""
        }

        let terms = queryTerms(from: query)
        guard terms.isEmpty == false else { return "" }

        var results: [SearchResult] = []

        for resource in resources {
            results.append(contentsOf: search(resource: resource, terms: terms))
            if results.count >= 10 { break }
        }

        guard results.isEmpty == false else { return "" }

        let snippets = results.prefix(10).map { result in
            """
            File: \(result.path)
            Match: \(result.snippet)
            """
        }
        .joined(separator: "\n\n")

        return """
        Search results from local files Console can read:
        \(snippets)
        """
    }

    private static func searchResources(for preferences: AppPreferences) -> [SearchResourceBookmark] {
        var resources: [SearchResourceBookmark] = []

        if preferences.fullFileSystemAccessEnabled {
            resources.append(.homeDirectory())
        }

        resources.append(contentsOf: preferences.searchResources)

        var seenPaths = Set<String>()
        return resources.filter { resource in
            seenPaths.insert(URL(fileURLWithPath: resource.lastKnownPath).standardizedFileURL.path).inserted
        }
    }

    private static func search(resource: SearchResourceBookmark, terms: [String]) -> [SearchResult] {
        let url: URL
        var didStartAccess = false

        if let bookmarkData = resource.bookmarkData {
            var isStale = false
            guard let resolvedURL = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else {
                return []
            }
            url = resolvedURL
            didStartAccess = url.startAccessingSecurityScopedResource()
        } else {
            url = URL(fileURLWithPath: resource.lastKnownPath)
        }

        defer {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        if resource.isDirectory {
            let scanLimit = resource.lastKnownPath == FileManager.default.homeDirectoryForCurrentUser.path ? 1_200 : 400
            return searchDirectory(url, terms: terms, scanLimit: scanLimit)
        }

        return searchFile(url, terms: terms).map { [$0] } ?? []
    }

    private static func searchDirectory(_ directoryURL: URL, terms: [String], scanLimit: Int) -> [SearchResult] {
        guard let enumerator = FileManager.default.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isHiddenKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var results: [SearchResult] = []
        var scannedFiles = 0

        for case let fileURL as URL in enumerator {
            guard scannedFiles < scanLimit, results.count < 10 else { break }
            if isSkippableDirectory(fileURL) {
                enumerator.skipDescendants()
                continue
            }
            guard isSearchableFile(fileURL) else { continue }
            scannedFiles += 1

            if let result = searchFile(fileURL, terms: terms) {
                results.append(result)
            }
        }

        return results
    }

    private static func searchFile(_ fileURL: URL, terms: [String]) -> SearchResult? {
        guard isSearchableFile(fileURL),
              let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
              (values.fileSize ?? 0) <= 350_000,
              let contents = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return nil
        }

        let lines = contents.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            let loweredLine = line.lowercased()
            if terms.contains(where: { loweredLine.contains($0) }) {
                let snippet = line
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .prefix(260)
                return SearchResult(
                    path: "\(fileURL.path):\(index + 1)",
                    snippet: String(snippet)
                )
            }
        }

        return nil
    }

    private static func isSkippableDirectory(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey]),
              values.isDirectory == true else {
            return false
        }

        let noisyDirectories: Set<String> = [
            ".build", ".git", ".svn", "Applications", "DerivedData", "Library",
            "Movies", "Music", "node_modules", "Pictures", "Pods", "vendor"
        ]

        return noisyDirectories.contains(url.lastPathComponent)
    }

    private static func queryTerms(from query: String) -> [String] {
        let separators = CharacterSet.alphanumerics.inverted
        let stopWords: Set<String> = [
            "the", "and", "for", "with", "that", "this", "what", "how", "why",
            "can", "you", "are", "from", "into", "make", "have", "file", "code"
        ]

        let candidates = query
            .lowercased()
            .components(separatedBy: separators)
            .filter { $0.count >= 3 && stopWords.contains($0) == false }

        var terms: [String] = []
        for candidate in candidates {
            terms.append(candidate)
            if terms.count == 10 {
                break
            }
        }
        return terms
    }

    private static func isSearchableFile(_ url: URL) -> Bool {
        let searchableExtensions: Set<String> = [
            "c", "cc", "cpp", "css", "csv", "h", "hpp", "html", "java", "js",
            "json", "jsx", "kt", "m", "md", "mm", "py", "rb", "rs", "sh",
            "swift", "toml", "ts", "tsx", "txt", "xml", "yaml", "yml"
        ]

        return searchableExtensions.contains(url.pathExtension.lowercased())
    }
}

private struct SearchResult {
    var path: String
    var snippet: String
}
