import SwiftUI

struct MessageRow: View {
    let message: Message
    let userInitials: String
    let copy: () -> Void
    let retry: () -> Void
    let export: () -> Void

    @State private var rowHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            MessageAvatar(role: message.role, userInitials: userInitials)
                .padding(.top, message.role == .assistant ? 2 : 0)

            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .center, spacing: 8) {
                    Text(message.sender)
                        .font(Typography.interface(11, .semibold))
                        .foregroundStyle(.secondary)

                    Text(message.date.shortRelativeLabel)
                        .font(Typography.interface(10))
                        .foregroundStyle(.tertiary)
                        .opacity(rowHovered ? 1 : 0.7)

                    Spacer(minLength: 0)

                    if message.role == .assistant {
                        MessageActions(copy: tappedCopy, retry: retry, export: export)
                            .opacity(rowHovered ? 1 : 0.0)
                            .animation(Theme.Motion.hover, value: rowHovered)
                    }
                }

                VStack(alignment: .leading, spacing: 13) {
                    ForEach(message.blocks) { block in
                        MessageBlockView(block: block, role: message.role)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onHover { rowHovered = $0 }
        // Optimized transition for older processors: simpler animation curve
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func tappedCopy() {
        copy()
        ToastCenter.shared.show("Copied", icon: "doc.on.doc.fill")
    }
}

// MARK: - Avatar

private struct MessageAvatar: View {
    let role: MessageRole
    let userInitials: String

    var body: some View {
        ZStack {
            if role == .user {
                Circle()
                    .fill(Theme.brandGradient)
                    .shadow(color: Color.black.opacity(0.16), radius: 3, x: 0, y: 1)
                Text(userInitials)
                    .font(Typography.interface(9, .bold))
                    .foregroundStyle(Color(nsColor: .windowBackgroundColor))
            } else {
                Circle()
                    .fill(Theme.subtleFill)
                    .overlay(Circle().stroke(Theme.separator.opacity(0.6), lineWidth: 0.5))
                TerminalIconView(size: 17)
                    .foregroundStyle(.primary.opacity(0.85))
            }
        }
        .frame(width: 26, height: 26)
    }
}

// MARK: - Block dispatch

private struct MessageBlockView: View {
    let block: MessageBlock
    let role: MessageRole

    var body: some View {
        switch block.kind {
        case .paragraph:
            if role == .user {
                UserBubble(text: block.text)
            } else if block.isThinkingPlaceholder {
                ThinkingIndicatorView()
            } else {
                AssistantMarkdownText(text: block.text)
            }
        case .code:
            CodeBlock(language: block.language ?? "Code", text: block.text)
        }
    }
}

// MARK: - User bubble

private struct UserBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Typography.prose(14.5))
            .lineSpacing(3)
            .foregroundStyle(.primary)
            .textSelection(.enabled)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.controlBackground)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Theme.separator.opacity(0.7), lineWidth: 1)
            }
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Assistant markdown text with optional streaming caret

private struct AssistantMarkdownText: View {
    let text: String

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            Text(markdownAttributedText)
                .font(Typography.prose(15.6))
                .lineSpacing(4.4)
                .foregroundStyle(.primary)
                .tint(Theme.accent)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var markdownAttributedText: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

// MARK: - Thinking indicator

private struct ThinkingIndicatorView: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        let wave = (sin((time * 4.2) + Double(index) * 0.72) + 1) / 2
                        Circle()
                            .fill(Theme.accent.opacity(0.45 + wave * 0.45))
                            .frame(width: 5, height: 5)
                            .scaleEffect(0.78 + (wave * 0.36))
                    }
                }
                .frame(width: 28, height: 12)

                Text("Thinking")
                    .font(Typography.interface(11, .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Theme.subtleFill)
            )
            .overlay(
                Capsule().stroke(Theme.separator.opacity(0.4), lineWidth: 0.5)
            )
        }
        .accessibilityLabel("Thinking")
    }
}

// MARK: - Code block with line numbers + copy confirmation

private struct CodeBlock: View {
    let language: String
    let text: String

    @State private var justCopied = false
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            codeBody
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.textBackground)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.separator.opacity(0.8), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onHover { hovering = $0 }
    }

    private var header: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Circle().fill(Color.red.opacity(0.62)).frame(width: 7, height: 7)
                Circle().fill(Color.yellow.opacity(0.62)).frame(width: 7, height: 7)
                Circle().fill(Color.green.opacity(0.62)).frame(width: 7, height: 7)
            }
            .padding(.trailing, 4)

            Text(language.uppercased())
                .font(Typography.interface(10, .semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)

            Spacer()

            Text("\(lineCount) line\(lineCount == 1 ? "" : "s")")
                .font(Typography.interface(10).monospacedDigit())
                .foregroundStyle(.secondary)
                .opacity(hovering ? 1 : 0.6)

            Button(action: copyContents) {
                HStack(spacing: 4) {
                    Image(systemName: justCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10, weight: .semibold))
                    Text(justCopied ? "Copied" : "Copy")
                        .font(Typography.interface(10.5, .medium))
                }
                .foregroundStyle(justCopied ? Theme.accent : Theme.secondaryText)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(Theme.subtleFill.opacity(hovering ? 1 : 0.6))
                )
            }
            .buttonStyle(PressableButtonStyle())
            .help("Copy code")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Theme.subtleFill)
        .overlay(
            Rectangle()
                .fill(Theme.separator.opacity(0.55))
                .frame(height: 1)
                .frame(maxHeight: .infinity, alignment: .bottom)
        )
    }

    private var codeBody: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 0) {
                lineNumbers
                Text(text)
                    .font(Typography.code(12.5))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var lineNumbers: some View {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        return VStack(alignment: .trailing, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, _ in
                Text("\(index + 1)")
                    .font(Typography.code(11.5).monospacedDigit())
                    .foregroundStyle(.secondary.opacity(0.55))
            }
        }
        .lineSpacing(0)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(Theme.subtleFill.opacity(0.35))
        .overlay(
            Rectangle()
                .fill(Theme.separator.opacity(0.4))
                .frame(width: 0.5)
                .frame(maxWidth: .infinity, alignment: .trailing)
        )
    }

    private var lineCount: Int {
        max(1, text.split(separator: "\n", omittingEmptySubsequences: false).count)
    }

    private func copyContents() {
        Pasteboard.copy(text)
        withAnimation(Theme.Motion.snap) {
            justCopied = true
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            await MainActor.run {
                withAnimation(Theme.Motion.snap) {
                    justCopied = false
                }
            }
        }
    }
}

// MARK: - Hover actions on assistant rows

private struct MessageActions: View {
    let copy: () -> Void
    let retry: () -> Void
    let export: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            MessageActionButton(title: "Copy", systemImage: "doc.on.doc", action: copy)
            MessageActionButton(title: "Retry", systemImage: "arrow.clockwise", action: retry)
            MessageActionButton(title: "Export", systemImage: "square.and.arrow.up", action: export)
        }
        .padding(3)
        .background(
            Capsule().fill(Theme.subtleFill)
        )
        .overlay(Capsule().stroke(Theme.separator.opacity(0.5), lineWidth: 0.5))
    }
}

private struct MessageActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 22, height: 22)
                .background(
                    Circle().fill(hovering ? Theme.hoverFill : Color.clear)
                )
        }
        .buttonStyle(.borderless)
        .foregroundStyle(hovering ? Color.primary : Theme.secondaryText)
        .help(title)
        .onHover { hovering = $0 }
        .animation(Theme.Motion.hover, value: hovering)
    }
}

// MARK: - Date helpers

private extension Date {
    var shortRelativeLabel: String {
        let interval = Date().timeIntervalSince(self)
        if interval < 60 { return "just now" }
        if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        }
        if Calendar.current.isDateInToday(self) {
            return formatted(date: .omitted, time: .shortened)
        }
        return formatted(date: .abbreviated, time: .shortened)
    }
}
