import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: ConsoleStore
    @State private var searchText: String = ""
    @State private var renamingID: UUID? = nil
    @State private var renameDraft: String = ""

    var body: some View {
        VStack(spacing: 0) {
            SidebarHeader(canCreateConversation: store.canCompose) {
                store.createConversation()
            }

            SidebarSearchField(text: $searchText)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            Divider()
                .opacity(0.6)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    navigationGroup
                    if !pinnedFiltered.isEmpty {
                        SidebarSection(title: "Pinned", systemImage: "pin.fill") {
                            ForEach(pinnedFiltered) { conversation in
                                conversationRow(for: conversation)
                            }
                        }
                    }
                    ForEach(ConversationSection.allCases) { section in
                        let conversations = sectionConversations(section)
                        if !conversations.isEmpty {
                            SidebarSection(title: section.rawValue, systemImage: nil) {
                                ForEach(conversations) { conversation in
                                    conversationRow(for: conversation)
                                }
                            }
                        }
                    }

                    if hasNoResults {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 18, weight: .light))
                                .foregroundStyle(.secondary)
                            Text("No matches for \"\(searchText)\"")
                                .font(Typography.interface(12, .medium))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 30)
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

    // MARK: - Sections

    private var navigationGroup: some View {
        VStack(alignment: .leading, spacing: 2) {
            SidebarNavigationButton(
                title: "Conversations",
                systemImage: "bubble.left.and.bubble.right",
                asset: nil,
                badge: store.conversations.isEmpty ? nil : "\(store.conversations.count)",
                isSelected: store.selectedItem == .conversations,
                action: store.showConversations
            )

            SidebarNavigationButton(
                title: "Temporary Chat",
                systemImage: nil,
                asset: .temporaryChat,
                badge: nil,
                isSelected: store.selectedItem == .temporaryChat,
                action: store.showTemporaryChat
            )

            SidebarNavigationButton(
                title: "Models",
                systemImage: nil,
                asset: .models,
                badge: store.installedModels.isEmpty ? nil : "\(store.installedModels.count)",
                isSelected: store.selectedItem == .models,
                action: store.showModels
            )
        }
    }

    // MARK: - Filtering helpers

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var pinnedFiltered: [Conversation] {
        filter(store.pinnedConversations())
    }

    private func sectionConversations(_ section: ConversationSection) -> [Conversation] {
        let base = store.conversations(in: section).filter { !$0.isPinned }
        return filter(base)
    }

    private func filter(_ items: [Conversation]) -> [Conversation] {
        guard !trimmedQuery.isEmpty else { return items }
        return items.filter { conversation in
            if conversation.displayTitle.localizedCaseInsensitiveContains(trimmedQuery) { return true }
            return conversation.messages.contains { $0.plainText.localizedCaseInsensitiveContains(trimmedQuery) }
        }
    }

    private var hasNoResults: Bool {
        !trimmedQuery.isEmpty && pinnedFiltered.isEmpty &&
            ConversationSection.allCases.allSatisfy { sectionConversations($0).isEmpty }
    }

    // MARK: - Row builder

    @ViewBuilder
    private func conversationRow(for conversation: Conversation) -> some View {
        ConversationRow(
            conversation: conversation,
            isSelected: store.selectedItem == .conversation(conversation.id),
            isRenaming: renamingID == conversation.id,
            renameDraft: $renameDraft,
            expirationLabel: store.expirationLabel(for: conversation),
            select: { store.selectedItem = .conversation(conversation.id) },
            beginRename: {
                renamingID = conversation.id
                renameDraft = conversation.displayTitle
            },
            commitRename: {
                if let id = renamingID {
                    store.renameConversation(id, to: renameDraft)
                    ToastCenter.shared.show("Renamed", icon: "pencil")
                }
                renamingID = nil
            },
            cancelRename: {
                renamingID = nil
            },
            togglePin: {
                store.togglePin(conversation.id)
                ToastCenter.shared.show(
                    conversation.isPinned ? "Unpinned" : "Pinned",
                    icon: conversation.isPinned ? "pin.slash" : "pin.fill"
                )
            },
            delete: {
                store.deleteConversation(conversation.id)
                ToastCenter.shared.show("Conversation deleted", icon: "trash")
            }
        )
    }
}

// MARK: - Header

private struct SidebarHeader: View {
    let canCreateConversation: Bool
    let newConversation: () -> Void

    @State private var iconBob = false

    var body: some View {
        HStack(spacing: 10) {
            BrandMark(iconBob: $iconBob)

            VStack(alignment: .leading, spacing: 1) {
                Text("Console")
                    .font(Typography.interface(15, .bold))
                    .foregroundStyle(.primary)
                Text("Coding assistant")
                    .font(Typography.interface(10, .medium))
                    .foregroundStyle(.secondary)
                    .opacity(0.85)
            }

            Spacer()

            Button(action: newConversation) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(canCreateConversation ? Theme.subtleFill : Color.clear)
                    )
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(!canCreateConversation)
            .help("New Conversation (⌘N)")
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .onAppear {
            withAnimation(Theme.Motion.drift) { iconBob.toggle() }
        }
    }
}

// MARK: - Search field

private struct SidebarSearchField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            TextField("Search conversations", text: $text)
                .textFieldStyle(.plain)
                .font(Typography.interface(12.5))
                .focused($isFocused)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.subtleFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isFocused ? Theme.accent.opacity(0.6) : Color.clear, lineWidth: 1)
        )
        .animation(Theme.Motion.hover, value: isFocused)
        .animation(Theme.Motion.hover, value: text.isEmpty)
    }
}

// MARK: - Section header

private struct SidebarSection<Content: View>: View {
    let title: String
    let systemImage: String?
    let content: Content

    init(title: String, systemImage: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Text(title.uppercased())
                    .font(Typography.interface(10, .semibold))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 3)

            content
        }
    }
}

// MARK: - Navigation button

private struct SidebarNavigationButton: View {
    let title: String
    let systemImage: String?
    let asset: ConsoleSymbolAsset?
    let badge: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                icon
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .frame(width: 18)
                    .symbolEffect(.bounce, value: isSelected)

                Text(title)
                    .font(Typography.interface(13, .medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)

                Spacer()

                if let badge {
                    Text(badge)
                        .font(Typography.interface(10, .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(
                            Capsule().fill(Theme.subtleFill)
                        )
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverHighlight(cornerRadius: 7, isSelected: isSelected)
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

// MARK: - Brand mark

private struct BrandMark: View {
    @Binding var iconBob: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Theme.subtleFill)
                .frame(width: 30, height: 30)
            TerminalIconView(size: 18)
                .foregroundStyle(Theme.brandGradient)
                .offset(y: iconBob ? -0.5 : 0.5)
        }
    }
}

// MARK: - Conversation row

private struct ConversationRow: View {
    let conversation: Conversation
    let isSelected: Bool
    let isRenaming: Bool
    @Binding var renameDraft: String
    let expirationLabel: String?
    let select: () -> Void
    let beginRename: () -> Void
    let commitRename: () -> Void
    let cancelRename: () -> Void
    let togglePin: () -> Void
    let delete: () -> Void

    @State private var showDeleteConfirm = false
    @FocusState private var renameFocused: Bool

    var body: some View {
        Button(action: select) {
            HStack(spacing: 9) {
                indicator

                if isRenaming {
                    TextField("", text: $renameDraft)
                        .textFieldStyle(.plain)
                        .font(Typography.interface(13, .medium))
                        .focused($renameFocused)
                        .onAppear { renameFocused = true }
                        .onSubmit(commitRename)
                        .onExitCommand(perform: cancelRename)
                } else {
                    Text(conversation.displayTitle)
                        .font(Typography.interface(13, .medium))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer()

                if conversation.isPinned && !isRenaming {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary.opacity(0.8))
                }

                if let expirationLabel, !isRenaming {
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
        .hoverHighlight(cornerRadius: 7, isSelected: isSelected)
        .contextMenu {
            Button(conversation.isPinned ? "Unpin" : "Pin", systemImage: conversation.isPinned ? "pin.slash" : "pin", action: togglePin)
            Button("Rename", systemImage: "pencil", action: beginRename)
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive) {
                showDeleteConfirm = true
            }
        }
        .alert("Delete this conversation?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive, action: delete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\"\(conversation.displayTitle)\" will be permanently removed.")
        }
    }

    private var indicator: some View {
        Circle()
            .fill(isSelected ? Theme.accent : Theme.tertiaryText)
            .frame(width: 5, height: 5)
            .overlay(
                Circle()
                    .stroke(Theme.accent.opacity(isSelected ? 0.25 : 0), lineWidth: 4)
            )
            .animation(Theme.Motion.snap, value: isSelected)
    }
}

// MARK: - Footer

private struct UserFooter: View {
    let name: String
    let initials: String

    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                Circle()
                    .fill(Theme.brandGradient)
                Text(initials)
                    .font(Typography.interface(10, .bold))
                    .foregroundStyle(Color(nsColor: .windowBackgroundColor))
            }
            .frame(width: 26, height: 26)
            .shadow(color: Color.black.opacity(0.18), radius: 3, x: 0, y: 1)

            VStack(alignment: .leading, spacing: 0) {
                Text(name)
                    .font(Typography.interface(13, .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("Local profile")
                    .font(Typography.interface(10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .hoverHighlight(cornerRadius: 6, selectedFill: nil)
            .help("Settings (⌘,)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
