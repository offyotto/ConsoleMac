import AppKit
import SwiftUI

/// A spotlight-style command palette presented over the main window. Supports
/// keyboard-only navigation: arrow keys move the selection, Return invokes.
struct CommandPaletteView: View {
    @ObservedObject var store: ConsoleStore
    @Binding var isPresented: Bool
    @Environment(\.openConsoleSettings) private var openConsoleSettings

    @State private var query: String = ""
    @State private var selectionIndex: Int = 0
    @FocusState private var fieldFocused: Bool

    // MARK: - Commands

    private var allCommands: [PaletteCommand] {
        var commands: [PaletteCommand] = []

        commands.append(PaletteCommand(
            icon: "square.and.pencil",
            title: "New Conversation",
            subtitle: "Start a fresh thread",
            shortcut: "⌘N",
            group: "Actions",
            action: { store.createConversation() }
        ))
        commands.append(PaletteCommand(
            icon: "bubble.left.and.bubble.right",
            title: "Show Conversations",
            subtitle: nil, shortcut: nil, group: "Navigation",
            action: store.showConversations
        ))
        commands.append(PaletteCommand(
            icon: "bubble.left",
            title: "Temporary Chat",
            subtitle: "Not saved to sidebar",
            shortcut: nil, group: "Navigation",
            action: store.showTemporaryChat
        ))
        commands.append(PaletteCommand(
            icon: "cpu",
            title: "Manage Models",
            subtitle: nil, shortcut: nil, group: "Navigation",
            action: store.showModels
        ))
        commands.append(PaletteCommand(
            icon: "gearshape",
            title: "Open Settings",
            subtitle: nil, shortcut: "⌘,", group: "Navigation",
            action: openConsoleSettings
        ))
        commands.append(PaletteCommand(
            icon: "folder.badge.plus",
            title: "Add Search Resource",
            subtitle: "Files or folders the agent can search",
            shortcut: "⇧⌘O", group: "Actions",
            action: store.addSearchResourcesFromOpenPanel
        ))
        if store.canExportSelectedConversation {
            commands.append(PaletteCommand(
                icon: "doc.on.doc",
                title: "Copy Conversation",
                subtitle: nil, shortcut: "⇧⌘C", group: "Actions",
                action: {
                    store.copySelectedConversation()
                    ToastCenter.shared.show("Conversation copied", icon: "doc.on.doc.fill")
                }
            ))
            commands.append(PaletteCommand(
                icon: "square.and.arrow.up",
                title: "Export Transcript",
                subtitle: nil, shortcut: "⇧⌘E", group: "Actions",
                action: store.exportSelectedConversation
            ))
        }
        if store.preferences.apiAgentModeEnabled {
            commands.append(PaletteCommand(
                icon: "wifi.slash",
                title: "Switch to Local Model Mode",
                subtitle: "Use a model installed on this Mac",
                shortcut: nil, group: "Mode",
                action: { store.updatePreferences { $0.apiAgentModeEnabled = false } }
            ))
        } else {
            commands.append(PaletteCommand(
                icon: "globe",
                title: "Switch to API Agent Mode",
                subtitle: "Use OpenRouter or OpenAI",
                shortcut: nil, group: "Mode",
                action: { store.updatePreferences { $0.apiAgentModeEnabled = true } }
            ))
        }

        for model in store.installedModels {
            commands.append(PaletteCommand(
                icon: "cpu",
                title: "Use Model: \(model.name)",
                subtitle: model.family,
                shortcut: nil, group: "Models",
                action: { store.selectModel(model.id) }
            ))
        }

        for conversation in store.conversations.prefix(20) {
            commands.append(PaletteCommand(
                icon: "bubble.left",
                title: conversation.displayTitle,
                subtitle: conversation.messages.last?.plainText.prefix(60).description ?? "Empty conversation",
                shortcut: nil, group: "Conversations",
                action: { store.selectedItem = .conversation(conversation.id) }
            ))
        }

        return commands
    }

    private var filteredCommands: [PaletteCommand] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return allCommands }
        return allCommands.filter { command in
            command.title.localizedCaseInsensitiveContains(trimmed)
                || (command.subtitle ?? "").localizedCaseInsensitiveContains(trimmed)
                || command.group.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("Type a command, model, or conversation…", text: $query)
                    .textFieldStyle(.plain)
                    .font(Typography.interface(15))
                    .focused($fieldFocused)
                    .onSubmit(runSelected)
                    .onExitCommand { isPresented = false }
                    .onChange(of: query) { _, _ in selectionIndex = 0 }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)

            Divider()

            if filteredCommands.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("No matches")
                        .font(Typography.interface(13, .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
                .padding(.vertical, 30)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 1) {
                            ForEach(Array(filteredCommands.enumerated()), id: \.element.id) { index, command in
                                CommandRow(
                                    command: command,
                                    isSelected: index == selectionIndex
                                ) {
                                    runCommand(command)
                                }
                                .id(index)
                                .onHover { hovering in
                                    if hovering { selectionIndex = index }
                                }
                            }
                        }
                        .padding(6)
                    }
                    .frame(maxHeight: 360)
                    .onChange(of: selectionIndex) { _, newValue in
                        withAnimation(.easeOut(duration: 0.08)) {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            }

            Divider()

            HStack(spacing: 16) {
                Label("↑↓ Navigate", systemImage: "arrow.up.arrow.down").font(Typography.interface(10.5))
                Label("↩ Run", systemImage: "return").font(Typography.interface(10.5))
                Label("Esc Close", systemImage: "escape").font(Typography.interface(10.5))
                Spacer()
                Text("\(filteredCommands.count) result\(filteredCommands.count == 1 ? "" : "s")")
                    .font(Typography.interface(10.5).monospacedDigit())
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Theme.subtleFill.opacity(0.5))
        }
        .frame(width: 560)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.separator.opacity(0.6), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.25), radius: 30, x: 0, y: 12)
        .onAppear {
            fieldFocused = true
            selectionIndex = 0
        }
        .background(KeyEventHandlingView { event in
            handleKey(event)
        })
    }

    private func runCommand(_ command: PaletteCommand) {
        isPresented = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            command.action()
        }
    }

    private func runSelected() {
        guard !filteredCommands.isEmpty,
              filteredCommands.indices.contains(selectionIndex) else { return }
        runCommand(filteredCommands[selectionIndex])
    }

    private func handleKey(_ event: NSEvent) -> NSEvent? {
        guard isPresented else { return event }
        switch event.keyCode {
        case 125: // down
            selectionIndex = min(filteredCommands.count - 1, selectionIndex + 1)
            return nil
        case 126: // up
            selectionIndex = max(0, selectionIndex - 1)
            return nil
        case 53: // escape
            isPresented = false
            return nil
        default:
            return event
        }
    }
}

// MARK: - Row

private struct PaletteCommand: Identifiable, Hashable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String?
    let shortcut: String?
    let group: String
    let action: () -> Void

    static func == (lhs: PaletteCommand, rhs: PaletteCommand) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

private struct CommandRow: View {
    let command: PaletteCommand
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: command.icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? Theme.accent : Theme.secondaryText)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 1) {
                    Text(command.title)
                        .font(Typography.interface(13, .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let subtitle = command.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(Typography.interface(11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text(command.group)
                    .font(Typography.interface(10, .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Theme.subtleFill))

                if let shortcut = command.shortcut {
                    Text(shortcut)
                        .font(Typography.interface(10.5, .semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 4).fill(Theme.subtleFill)
                        )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Theme.accent.opacity(0.14) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Theme.accent.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Local key event interceptor

private struct KeyEventHandlingView: NSViewRepresentable {
    let handler: (NSEvent) -> NSEvent?

    func makeNSView(context: Context) -> NSView {
        let view = MonitorHostingView()
        view.handler = handler
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? MonitorHostingView)?.handler = handler
    }

    final class MonitorHostingView: NSView {
        var handler: ((NSEvent) -> NSEvent?)?
        private nonisolated(unsafe) var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil, monitor == nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                    self?.handler?(event) ?? event
                }
            } else if window == nil, let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}
