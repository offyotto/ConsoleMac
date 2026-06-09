import SwiftUI

/// A polished cheat-sheet sheet listing the app's keyboard shortcuts.
struct KeyboardShortcutsView: View {
    @Binding var isPresented: Bool

    private let groups: [ShortcutGroup] = [
        ShortcutGroup(title: "Conversation", items: [
            ShortcutItem(action: "New conversation", keys: ["⌘", "N"]),
            ShortcutItem(action: "Send message", keys: ["⌘", "↩"]),
            ShortcutItem(action: "New line", keys: ["⇧", "↩"]),
            ShortcutItem(action: "Copy conversation", keys: ["⇧", "⌘", "C"]),
            ShortcutItem(action: "Export transcript", keys: ["⇧", "⌘", "E"]),
        ]),
        ShortcutGroup(title: "Navigation", items: [
            ShortcutItem(action: "Quick switch", keys: ["⌘", "K"]),
            ShortcutItem(action: "Add files", keys: ["⇧", "⌘", "O"]),
            ShortcutItem(action: "Settings", keys: ["⌘", ","]),
            ShortcutItem(action: "Show shortcuts", keys: ["⌘", "/"]),
        ]),
        ShortcutGroup(title: "Window", items: [
            ShortcutItem(action: "Hide window", keys: ["⌘", "H"]),
            ShortcutItem(action: "Quit", keys: ["⌘", "Q"]),
        ])
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Keyboard Shortcuts")
                        .font(Typography.interface(17, .semibold))
                    Text("Move faster with the keyboard.")
                        .font(Typography.interface(12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(7)
                        .background(Circle().fill(Theme.subtleFill))
                }
                .buttonStyle(PressableButtonStyle())
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 14)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(groups) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.title.uppercased())
                                .font(Typography.interface(10, .semibold))
                                .tracking(0.7)
                                .foregroundStyle(.secondary)

                            VStack(spacing: 0) {
                                ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                                    HStack {
                                        Text(item.action)
                                            .font(Typography.interface(13))
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        HStack(spacing: 4) {
                                            ForEach(item.keys, id: \.self) { key in
                                                KeyCap(key: key)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    if index < group.items.count - 1 {
                                        Divider().opacity(0.4)
                                    }
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Theme.subtleFill.opacity(0.65))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Theme.separator.opacity(0.5), lineWidth: 0.5)
                            )
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
            }
        }
        .frame(width: 460, height: 560)
        .background(Theme.windowBackground)
    }
}

private struct KeyCap: View {
    let key: String

    var body: some View {
        Text(key)
            .font(Typography.interface(11.5, .semibold).monospacedDigit())
            .foregroundStyle(.primary)
            .frame(minWidth: 22, minHeight: 22)
            .padding(.horizontal, 5)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Theme.controlBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(Theme.separator.opacity(0.7), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 1, x: 0, y: 1)
    }
}

private struct ShortcutGroup: Identifiable {
    let id = UUID()
    let title: String
    let items: [ShortcutItem]
}

private struct ShortcutItem: Identifiable {
    let id = UUID()
    let action: String
    let keys: [String]
}
