import SwiftUI

struct MessagesView: View {
    @ObservedObject var store: ConsoleStore

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if let conversation = store.selectedConversation, conversation.messages.isEmpty {
                    EmptyThreadView(
                        modelName: store.selectedModel?.name,
                        isTemporary: store.isTemporaryChatSelected,
                        canCompose: store.canCompose,
                        applyPrompt: { store.draft = $0 }
                    )
                    .frame(maxWidth: .infinity, minHeight: 380)
                    .padding(.top, 48)
                } else {
                    LazyVStack(alignment: .leading, spacing: 26) {
                        if let firstDate = store.selectedConversation?.messages.first?.date {
                            DayDivider(label: firstDate.conversationDayLabel)
                        }

                        ForEach(store.selectedConversation?.messages ?? []) { message in
                            MessageRow(
                                message: message,
                                userInitials: store.preferences.userInitials,
                                copy: { store.copy(message) },
                                retry: { store.retry(message) },
                                export: { store.export(message) }
                            )
                            .id(message.id)
                        }

                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding(.horizontal, 34)
                    .padding(.top, 24)
                    .padding(.bottom, 28)
                    .frame(maxWidth: 920, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                    // Optimized animation for older processors: uses spring with higher damping
                    .animation(Theme.Motion.entrance, value: store.selectedConversation?.messages.count ?? 0)
                }
            }
            .onAppear {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
            .onChange(of: store.selectedConversation?.messages.count ?? 0) {
                withAnimation(.easeOut(duration: 0.22)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: bottomScrollTrigger) {
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    private var bottomScrollTrigger: String {
        guard let conversation = store.selectedConversation,
              let message = conversation.messages.last else {
            return "empty"
        }

        return "\(conversation.id.uuidString)-\(message.id.uuidString)-\(message.plainText.count)"
    }
}

// MARK: - Empty thread

private struct EmptyThreadView: View {
    let modelName: String?
    let isTemporary: Bool
    let canCompose: Bool
    let applyPrompt: (String) -> Void

    @State private var floating = false

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Theme.subtleFill)
                    .frame(width: 78, height: 78)
                    .overlay(Circle().stroke(Theme.separator.opacity(0.5), lineWidth: 0.5))

                if isTemporary {
                    ConsoleSymbolView(asset: .temporaryChat, size: 34)
                        .foregroundStyle(.secondary)
                } else {
                    TerminalIconView(size: 36)
                        .foregroundStyle(.primary.opacity(0.75))
                }
            }
            .offset(y: floating ? -4 : 4)
            .onAppear {
                withAnimation(Theme.Motion.drift) { floating.toggle() }
            }

            VStack(spacing: 6) {
                Text(isTemporary ? "Temporary chat" : (modelName ?? "No model selected"))
                    .font(Typography.interface(20, .semibold))
                    .foregroundStyle(.primary)

                Text(emptyText)
                    .font(Typography.interface(13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }

            if canCompose {
                SuggestionChips(applyPrompt: applyPrompt)
                    .padding(.top, 6)
            }
        }
    }

    private var emptyText: String {
        if modelName == nil && !isTemporary {
            return "Install a model from the Models tab before sending."
        }
        if isTemporary {
            return "Messages here aren't saved to the sidebar. Great for one-off questions."
        }
        return "Start with a prompt, command, file question, or repo task. Tap a suggestion below to get going."
    }
}

private struct SuggestionChips: View {
    let applyPrompt: (String) -> Void

    private let columns = [GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(ConsoleStore.suggestedPrompts) { suggestion in
                SuggestionChip(suggestion: suggestion) {
                    applyPrompt(suggestion.prompt)
                }
            }
        }
        .frame(maxWidth: 620)
        .padding(.horizontal, 24)
    }
}

private struct SuggestionChip: View {
    let suggestion: SuggestedPrompt
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: suggestion.icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 1) {
                    Text(suggestion.title)
                        .font(Typography.interface(12.5, .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(suggestion.prompt.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(Typography.interface(10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .opacity(hovering ? 1 : 0)
                    .offset(x: hovering ? 0 : -3)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(hovering ? Theme.hoverFill : Theme.subtleFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Theme.separator.opacity(hovering ? 0.9 : 0.5), lineWidth: 0.5)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .onHover { hovering = $0 }
        .animation(Theme.Motion.hover, value: hovering)
    }
}

// MARK: - Day divider

private struct DayDivider: View {
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            Rectangle().fill(Theme.separator).frame(height: 0.5)
            Text(label)
                .font(Typography.interface(10.5, .semibold))
                .tracking(0.4)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Capsule().fill(Theme.subtleFill))
            Rectangle().fill(Theme.separator).frame(height: 0.5)
        }
        .padding(.horizontal, 2)
    }
}

private extension Date {
    var conversationDayLabel: String {
        if Calendar.current.isDateInToday(self) {
            return "Today"
        }
        if Calendar.current.isDateInYesterday(self) {
            return "Yesterday"
        }
        return formatted(date: .abbreviated, time: .omitted)
    }
}
