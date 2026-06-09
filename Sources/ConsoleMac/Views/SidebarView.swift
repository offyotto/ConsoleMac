import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: ConsoleStore

    var body: some View {
        VStack(spacing: 0) {
            SidebarHeader(canCreateConversation: store.canCompose) {
                store.createConversation()
            }

            Divider()

            Color.clear
                .frame(height: 5)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        SidebarNavigationButton(
                            title: "Conversations",
                            systemImage: "bubble.left.and.bubble.right",
                            asset: nil,
                            isSelected: store.selectedItem == .conversations,
                            action: store.showConversations
                        )

                        SidebarNavigationButton(
                            title: "Temporary Chat",
                            systemImage: nil,
                            asset: .temporaryChat,
                            isSelected: store.selectedItem == .temporaryChat,
                            action: store.showTemporaryChat
                        )

                        SidebarNavigationButton(
                            title: "Models",
                            systemImage: nil,
                            asset: .models,
                            isSelected: store.selectedItem == .models,
                            action: store.showModels
                        )
                    }

                    ForEach(ConversationSection.allCases) { section in
                        let conversations = store.conversations(in: section)
                        if !conversations.isEmpty {
                            SidebarSection(title: section.rawValue) {
                                ForEach(conversations) { conversation in
                                    ConversationRow(
                                        conversation: conversation,
                                        isSelected: store.selectedItem == .conversation(conversation.id),
                                        expirationLabel: store.expirationLabel(for: conversation)
                                    ) {
                                        store.selectedItem = .conversation(conversation.id)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }

            Divider()

            UserFooter(name: store.preferences.displayUserName, initials: store.preferences.userInitials)
        }
        .background(.regularMaterial)
    }
}

private struct SidebarHeader: View {
    let canCreateConversation: Bool
    let newConversation: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            BrandMark()

            Text("Console")
                .font(Typography.interface(15, .bold))
                .foregroundStyle(.primary)

            Spacer()

            Button(action: newConversation) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(.borderless)
            .disabled(!canCreateConversation)
            .help("New Conversation")
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 15)
    }
}

private struct SidebarSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(Typography.interface(11, .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.top, 6)
                .padding(.bottom, 3)

            content
        }
    }
}

private struct SidebarNavigationButton: View {
    let title: String
    let systemImage: String?
    let asset: ConsoleSymbolAsset?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                icon
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .frame(width: 18)

                Text(title)
                    .font(Typography.interface(13, .medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)

                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSelected ? Theme.subtleFill : Color.clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    @ViewBuilder
    private var icon: some View {
        if let asset {
            ConsoleSymbolView(asset: asset, size: 15)
        } else {
            Image(systemName: systemImage ?? "circle")
                .font(.system(size: 13, weight: .semibold))
        }
    }
}

private struct BrandMark: View {
    var body: some View {
        TerminalIconView(size: 25)
            .foregroundStyle(.primary)
        .frame(width: 30, height: 30)
    }
}

private struct ConversationRow: View {
    let conversation: Conversation
    let isSelected: Bool
    let expirationLabel: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Circle()
                    .fill(isSelected ? Color.primary : Theme.tertiaryText)
                    .frame(width: 4, height: 4)

                Text(conversation.title)
                    .font(Typography.interface(13, .medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                if let expirationLabel {
                    ConsoleSymbolView(asset: .retention, size: 13)
                        .foregroundStyle(isSelected ? Color.primary.opacity(0.75) : Theme.secondaryText.opacity(0.75))
                        .help("Deletes \(expirationLabel)")
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSelected ? Theme.subtleFill : Color.clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct UserFooter: View {
    let name: String
    let initials: String

    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                Circle()
                    .fill(Color.primary)
                Text(initials)
                    .font(Typography.interface(10, .bold))
                    .foregroundStyle(Color(nsColor: .windowBackgroundColor))
            }
            .frame(width: 24, height: 24)

            Text(name)
                .font(Typography.interface(13, .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
