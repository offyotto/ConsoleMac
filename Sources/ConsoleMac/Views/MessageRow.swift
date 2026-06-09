import SwiftUI

struct MessageRow: View {
    let message: Message
    let userInitials: String
    let copy: () -> Void
    let retry: () -> Void
    let export: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            MessageAvatar(role: message.role, userInitials: userInitials)
                .padding(.top, message.role == .assistant ? 2 : 0)

            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .center, spacing: 8) {
                    Text(message.sender)
                        .font(Typography.interface(11, .semibold))
                        .foregroundStyle(.secondary)

                    if message.role == .assistant {
                        MessageActions(copy: copy, retry: retry, export: export)
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
    }
}

private struct MessageAvatar: View {
    let role: MessageRole
    let userInitials: String

    var body: some View {
        ZStack {
            if role == .user {
                Circle()
                    .fill(Color.primary)
                Text(userInitials)
                    .font(Typography.interface(9, .bold))
                    .foregroundStyle(Color(nsColor: .windowBackgroundColor))
            } else {
                TerminalIconView(size: 22)
                    .foregroundStyle(.primary.opacity(0.82))
            }
        }
        .frame(width: 24, height: 24)
    }
}

private struct MessageBlockView: View {
    let block: MessageBlock
    let role: MessageRole

    var body: some View {
        switch block.kind {
        case .paragraph:
            if role == .user {
                Text(block.text)
                    .font(Typography.prose(14.5))
                    .lineSpacing(3)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Theme.controlBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Theme.separator.opacity(0.7), lineWidth: 1)
                    }
                    .fixedSize(horizontal: false, vertical: true)
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

private struct AssistantMarkdownText: View {
    let text: String

    var body: some View {
        Text(markdownAttributedText)
            .font(Typography.prose(15.6))
            .lineSpacing(4.4)
            .foregroundStyle(.primary)
            .tint(Theme.accent)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var markdownAttributedText: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

private struct ThinkingIndicatorView: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        let wave = (sin((time * 4.2) + Double(index) * 0.72) + 1) / 2
                        Circle()
                            .fill(Color.primary.opacity(0.42 + (wave * 0.36)))
                            .frame(width: 5, height: 5)
                            .scaleEffect(0.78 + (wave * 0.34))
                    }
                }
                .frame(width: 24, height: 12)

                Text("Thinking")
                    .font(Typography.interface(11, .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(Theme.subtleFill, in: Capsule())
        }
        .accessibilityLabel("Thinking")
    }
}

private struct CodeBlock: View {
    let language: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language)
                    .font(Typography.interface(10, .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    Pasteboard.copy(text)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copy")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Theme.subtleFill)

            ScrollView(.horizontal, showsIndicators: false) {
                Text(text)
                    .font(Typography.code(12.5))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Theme.textBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.separator.opacity(0.8), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

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
        .background(Theme.subtleFill, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct MessageActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .help(title)
    }
}
