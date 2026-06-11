import AppKit
import SwiftUI

struct CommandPaletteView: View {
    @ObservedObject var store: ConsoleStore
    @Binding var isPresented: Bool
    @Environment(\.openConsoleSettings) private var openConsoleSettings

    @State private var query: String = ""
    @State private var selectionIndex: Int = 0
    @FocusState private var fieldFocused: Bool

    private var allCommands: [PaletteCommand] {
        var commands: [PaletteCommand] = []

        commands.append(PaletteCommand(
            icon: "square.and.pencil",
            title: "New Conversation",
            subtitle: nil,
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
            subtitle: "Files or folders",
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
                    ToastCenter.shared.show("Copied", icon: "doc.on.doc.fill")
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
                title: "Use Local Model Mode",
                subtitle: nil,
                shortcut: nil, group: "Mode",
                action: { store.updatePreferences { $0.apiAgentModeEnabled = false } }
            ))
        } else {
            commands.append(PaletteCommand(
                icon: "globe",
                title: "Use API Agent Mode",
                subtitle: nil,
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
                subtitle: conversation.messages.last?.plainText.prefix(60).description ?? "Empty",
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
        let commands = filteredCommands

        VStack(spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("Search commands, models, conversations…", text: $query)
                    .textFieldStyle(.plain)
                    .font(Typography.interface(15))
                    .focused($fieldFocused)
                    .onSubmit(runSelected)
                    .onExitCommand { isPresented = false }
                    .onChange(of: query) { _, _ in
                        selectionIndex = 0
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)

            Divider()

            if commands.isEmpty {
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
                            ForEach(Array(commands.enumerated()), id: \.element.id) { index, command in
                                CommandRow(
                                    command: command,
                                    isSelected: index == selectionIndex
                                ) {
                                    runCommand(command)
                                }
                                .id(command.id)
                            }
                        }
                        .padding(6)
                    }
                    .frame(maxHeight: 360)
                    .onChange(of: selectionIndex) { _, newValue in
                        scrollToSelection(newValue, in: commands, proxy: proxy)
                    }
                    .onChange(of: commands.map(\.id)) { _, nextIDs in
                        selectionIndex = 0
                        guard let firstID = nextIDs.first else { return }
                        DispatchQueue.main.async {
                            proxy.scrollTo(firstID, anchor: .top)
                        }
                    }
                    .onAppear {
                        scrollToSelection(selectionIndex, in: commands, proxy: proxy, animated: false)
                    }
                }
            }

            Divider()

            HStack(spacing: 16) {
                Text("↑↓ Navigate")
                    .font(Typography.interface(10.5))
                Text("↩ Run")
                    .font(Typography.interface(10.5))
                Text("Esc Close")
                    .font(Typography.interface(10.5))
                Spacer()
                Text("\(commands.count) result\(commands.count == 1 ? "" : "s")")
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
            selectionIndex = 0
            DispatchQueue.main.async {
                fieldFocused = true
            }
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
        let commands = filteredCommands
        guard !commands.isEmpty else { return }
        runCommand(commands[clampedSelectionIndex(in: commands)])
    }

    private func handleKey(_ event: NSEvent) -> NSEvent? {
        guard isPresented else { return event }
        let commands = filteredCommands

        switch event.keyCode {
        case 125:
            guard !commands.isEmpty else { return nil }
            selectionIndex = min(commands.count - 1, selectionIndex + 1)
            return nil
        case 126:
            guard !commands.isEmpty else { return nil }
            selectionIndex = max(0, selectionIndex - 1)
            return nil
        case 121:
            guard !commands.isEmpty else { return nil }
            selectionIndex = min(commands.count - 1, selectionIndex + 8)
            return nil
        case 116:
            guard !commands.isEmpty else { return nil }
            selectionIndex = max(0, selectionIndex - 8)
            return nil
        case 119:
            guard !commands.isEmpty else { return nil }
            selectionIndex = commands.count - 1
            return nil
        case 115:
            selectionIndex = 0
            return nil
        case 36, 76:
            runSelected()
            return nil
        case 53:
            isPresented = false
            return nil
        default:
            return event
        }
    }

    private func clampedSelectionIndex(in commands: [PaletteCommand]) -> Int {
        min(max(selectionIndex, 0), max(commands.count - 1, 0))
    }

    private func scrollToSelection(
        _ index: Int,
        in commands: [PaletteCommand],
        proxy: ScrollViewProxy,
        animated: Bool = true
    ) {
        guard commands.isEmpty == false else { return }
        let clampedIndex = min(max(index, 0), commands.count - 1)
        let id = commands[clampedIndex].id
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeOut(duration: 0.10)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            } else {
                proxy.scrollTo(id, anchor: .center)
            }
        }
    }
}

// MARK: - Row

private struct PaletteCommand: Identifiable, Hashable {
    let id: String
    let icon: String
    let title: String
    let subtitle: String?
    let shortcut: String?
    let group: String
    let action: () -> Void

    init(
        icon: String,
        title: String,
        subtitle: String?,
        shortcut: String?,
        group: String,
        action: @escaping () -> Void
    ) {
        self.id = "\(group)|\(title)"
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.shortcut = shortcut
        self.group = group
        self.action = action
    }

    static func == (lhs: PaletteCommand, rhs: PaletteCommand) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

private struct CommandRow: View {
    let command: PaletteCommand
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

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
                .fill(rowFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Theme.accent.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .onHover { isHovering = $0 }
        .animation(Theme.Motion.hover, value: isHovering)
    }

    private var rowFill: Color {
        if isSelected { return Theme.accent.opacity(0.14) }
        return isHovering ? Theme.hoverFill : Color.clear
    }
}

// MARK: - Key event interceptor

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
