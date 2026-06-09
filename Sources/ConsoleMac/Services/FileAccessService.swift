import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
enum FileAccessService {
    static func pickSearchResources() -> [SearchResourceBookmark] {
        let panel = NSOpenPanel()
        panel.title = "Choose Files or Folders for Agent Search"
        panel.message = "Console can search these paths when preparing local model prompts."
        panel.prompt = "Add"
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.resolvesAliases = true

        guard panel.runModal() == .OK else { return [] }

        return panel.urls.map { url in
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
            return SearchResourceBookmark(
                displayName: url.lastPathComponent,
                lastKnownPath: url.path,
                isDirectory: values?.isDirectory ?? false
            )
        }
    }

    static func exportTranscript(title: String, body: String) {
        exportMarkdown(
            title: "Export Transcript",
            message: "Choose where to save this conversation transcript.",
            prompt: "Export",
            filename: sanitizedFilename(from: title) + ".md",
            body: body
        )
    }

    static func exportMessage(sender: String, body: String) {
        exportMarkdown(
            title: "Export Message",
            message: "Choose where to save this message.",
            prompt: "Export",
            filename: sanitizedFilename(from: "\(sender) Message") + ".md",
            body: body
        )
    }

    private static func exportMarkdown(
        title: String,
        message: String,
        prompt: String,
        filename: String,
        body: String
    ) {
        let panel = NSSavePanel()
        panel.title = title
        panel.message = message
        panel.prompt = prompt
        panel.nameFieldStringValue = filename
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText, .plainText]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try body.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            NSSound.beep()
        }
    }

    private static func sanitizedFilename(from title: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\:?%*|\"<>")
            .union(.newlines)
        let components = title.components(separatedBy: invalidCharacters)
        let sanitized = components
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.isEmpty ? "Console Transcript" : sanitized
    }
}
