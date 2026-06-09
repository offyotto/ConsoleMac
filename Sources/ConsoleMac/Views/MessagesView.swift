import SwiftUI

struct MessagesView: View {
    @ObservedObject var store: ConsoleStore

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if let conversation = store.selectedConversation, conversation.messages.isEmpty {
                    EmptyThreadView(modelName: store.selectedModel?.name, isTemporary: store.isTemporaryChatSelected)
                        .frame(maxWidth: .infinity, minHeight: 360)
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

private struct EmptyThreadView: View {
    let modelName: String?
    let isTemporary: Bool

    var body: some View {
        VStack(spacing: 10) {
            if isTemporary {
                ConsoleSymbolView(asset: .temporaryChat, size: 34)
                    .foregroundStyle(.secondary)
            } else {
                TerminalIconView(size: 34)
                    .foregroundStyle(.secondary)
            }

            Text(isTemporary ? "Temporary Chat" : (modelName ?? "No model selected"))
                .font(Typography.interface(18, .semibold))
                .foregroundStyle(.primary)

            Text(emptyText)
                .font(Typography.interface(13))
                .foregroundStyle(.secondary)
        }
    }

    private var emptyText: String {
        if modelName == nil {
            return "Install a model from the Models tab before sending."
        }

        if isTemporary {
            return "Messages here are not saved to the sidebar."
        }

        return "Start with a prompt, command, file question, or repo task."
    }
}

private struct DayDivider: View {
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Theme.separator)
                .frame(height: 1)
            Text(label)
                .font(Typography.interface(11, .medium))
                .foregroundStyle(.secondary)
            Rectangle()
                .fill(Theme.separator)
                .frame(height: 1)
        }
        .padding(.horizontal, 2)
    }
}

private extension Date {
    var conversationDayLabel: String {
        if Calendar.current.isDateInToday(self) {
            return "Today"
        }

        return formatted(date: .abbreviated, time: .omitted)
    }
}
