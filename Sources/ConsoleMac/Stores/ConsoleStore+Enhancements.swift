import Foundation

// MARK: - Conversation pinning, renaming, deletion
//
// These additions live in an extension so the core ConsoleStore file is
// untouched. Pinned state is persisted by piggy-backing on the conversation
// title with an invisible marker, which keeps the storage format backwards
// compatible.

private let pinnedTitleMarker = "\u{200B}\u{2605}\u{200B}" // zero-width-pin-zero-width

extension Conversation {
    /// Whether this conversation has been pinned by the user.
    var isPinned: Bool {
        title.hasPrefix(pinnedTitleMarker)
    }

    /// Title with the internal pin marker stripped, suitable for display.
    var displayTitle: String {
        guard isPinned else { return title }
        return String(title.dropFirst(pinnedTitleMarker.count))
    }
}

extension ConsoleStore {

    // MARK: Pinning

    /// Toggle the pinned state of a conversation.
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

    /// Conversations split into pinned and unpinned buckets, both sorted by
    /// most-recently updated.
    func pinnedConversations() -> [Conversation] {
        conversations
            .filter { $0.isPinned }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: Rename

    /// Set a custom title on a conversation, preserving its pinned state.
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

    /// Permanently remove a saved conversation. Updates selection so the
    /// detail pane doesn't point at a dangling id.
    func deleteConversation(_ conversationID: UUID) {
        if case .conversation(let selected) = selectedItem, selected == conversationID {
            selectedItem = .conversations
        }
        conversations.removeAll { $0.id == conversationID }
    }

    // MARK: Stop generation
    //
    // Best-effort cancellation: flips the generating flag back off. The model
    // task itself is owned privately by ConsoleStore; this is a UI surface so
    // the user can dismiss the "Thinking" state when they want to move on.
    func requestStopGeneration() {
        guard isGeneratingResponse else { return }
        isGeneratingResponse = false
    }
}

// MARK: - Quick prompt suggestions

extension ConsoleStore {
    /// Curated prompt seeds shown on empty threads + the home view.
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
            title: "Ask a focused question",
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
