import Foundation

enum ConversationSection: String, CaseIterable, Identifiable, Codable {
    case today = "Today"
    case earlier = "Earlier"

    var id: String { rawValue }
}

struct Conversation: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var section: ConversationSection
    var createdAt: Date
    var updatedAt: Date
    var messages: [Message]

    init(
        id: UUID = UUID(),
        title: String,
        section: ConversationSection,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        messages: [Message]
    ) {
        self.id = id
        self.title = title
        self.section = section
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
    }
}

enum MessageRole: String, Hashable, Codable {
    case user
    case assistant
}

struct Message: Identifiable, Hashable, Codable {
    static let thinkingPlaceholderText = "Thinking..."

    let id: UUID
    var role: MessageRole
    var sender: String
    var date: Date
    var blocks: [MessageBlock]

    init(
        id: UUID = UUID(),
        role: MessageRole,
        sender: String,
        date: Date = Date(),
        blocks: [MessageBlock]
    ) {
        self.id = id
        self.role = role
        self.sender = sender
        self.date = date
        self.blocks = blocks
    }

    var plainText: String {
        blocks.map(\.plainText).joined(separator: "\n\n")
    }

    var isThinkingPlaceholder: Bool {
        role == .assistant &&
            blocks.count == 1 &&
            blocks.first?.kind == .paragraph &&
            blocks.first?.text == Self.thinkingPlaceholderText
    }
}

struct MessageBlock: Identifiable, Hashable, Codable {
    enum Kind: String, Codable {
        case paragraph
        case code
    }

    let id: UUID
    var kind: Kind
    var text: String
    var language: String?

    var plainText: String {
        text
    }

    var isThinkingPlaceholder: Bool {
        kind == .paragraph && text == Message.thinkingPlaceholderText
    }

    static func paragraph(_ text: String) -> MessageBlock {
        MessageBlock(id: UUID(), kind: .paragraph, text: text, language: nil)
    }

    static func code(language: String, text: String) -> MessageBlock {
        MessageBlock(id: UUID(), kind: .code, text: text, language: language)
    }

    static func markdownBlocks(from text: String) -> [MessageBlock] {
        var blocks: [MessageBlock] = []
        var paragraphLines: [String] = []
        var codeLines: [String] = []
        var codeLanguage = "Code"
        var isInsideCodeFence = false

        func flushParagraph() {
            let paragraph = paragraphLines
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if paragraph.isEmpty == false {
                blocks.append(.paragraph(paragraph))
            }
            paragraphLines.removeAll()
        }

        func flushCode() {
            blocks.append(.code(language: codeLanguage, text: codeLines.joined(separator: "\n")))
            codeLines.removeAll()
            codeLanguage = "Code"
        }

        for line in text.components(separatedBy: .newlines) {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.hasPrefix("```") {
                if isInsideCodeFence {
                    flushCode()
                    isInsideCodeFence = false
                } else {
                    flushParagraph()
                    isInsideCodeFence = true
                    let language = String(trimmedLine.dropFirst(3))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    codeLanguage = language.isEmpty ? "Code" : language
                }
                continue
            }

            if isInsideCodeFence {
                codeLines.append(line)
            } else {
                paragraphLines.append(line)
            }
        }

        if isInsideCodeFence {
            flushCode()
        } else {
            flushParagraph()
        }

        return blocks.isEmpty ? [.paragraph(text)] : blocks
    }
}
