import Foundation

private let pinnedTitleMarker = "\u{200B}\u{2605}\u{200B}"

extension Conversation {
    var isPinned: Bool {
        title.hasPrefix(pinnedTitleMarker)
    }

    var displayTitle: String {
        guard isPinned else { return title }
        return String(title.dropFirst(pinnedTitleMarker.count))
    }
}

extension ConsoleStore {

    // MARK: Pinning

    func togglePin(_ conversationID: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        var conversation = conversations[index]
        if conversation.isPinned {
            conversation.title = conversation.displayTitle
        } else {
            conversation.title = pinnedTitleMarker + conversation.displayTitle
        }
        conversations[index] = conversation
    }

    func isPinned(_ conversationID: UUID) -> Bool {
        conversation(id: conversationID)?.isPinned ?? false
    }

    func pinnedConversations() -> [Conversation] {
        conversations
            .filter { $0.isPinned }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: Rename

    func renameConversation(_ conversationID: UUID, to newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        var conversation = conversations[index]
        let wasPinned = conversation.isPinned
        conversation.title = wasPinned ? pinnedTitleMarker + trimmed : trimmed
        conversations[index] = conversation
    }

    // MARK: Delete

    func deleteConversation(_ conversationID: UUID) {
        if case .conversation(let selected) = selectedItem, selected == conversationID {
            selectedItem = .conversations
        }
        conversations.removeAll { $0.id == conversationID }
    }

    // MARK: Stop generation

    func requestStopGeneration() {
        guard isGeneratingResponse else { return }
        isGeneratingResponse = false
    }
}

// MARK: - Suggested prompts

extension ConsoleStore {
    static let suggestedPrompts: [SuggestedPrompt] = [
        SuggestedPrompt(
            icon: "wand.and.stars",
            title: "Explain this codebase",
            prompt: "Walk me through the architecture of the files I've added as search resources."
        ),
        SuggestedPrompt(
            icon: "ladybug",
            title: "Find a bug",
            prompt: "Help me debug an issue. I'll paste the error and the relevant function next."
        ),
        SuggestedPrompt(
            icon: "doc.text.magnifyingglass",
            title: "Review a diff",
            prompt: "Review this change for correctness, edge cases, and style. ```\n\n```"
        ),
        SuggestedPrompt(
            icon: "bolt",
            title: "Write a script",
            prompt: "Write a small Swift script that "
        ),
        SuggestedPrompt(
            icon: "terminal",
            title: "Explain a shell command",
            prompt: "Explain what this shell command does, step by step: `"
        ),
        SuggestedPrompt(
            icon: "questionmark.circle",
            title: "Ask a question",
            prompt: "In Swift, how do I "
        )
    ]
}

struct SuggestedPrompt: Identifiable, Hashable {
    let id = UUID()
    let icon: String
    let title: String
    let prompt: String
}
