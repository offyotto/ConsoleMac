import SwiftUI

struct ComposerView: View {
    @ObservedObject var store: ConsoleStore
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                Button {
                    store.addSearchResourcesFromOpenPanel()
                } label: {
                    Image(systemName: "paperclip")
                }
                .buttonStyle(ComposerIconButtonStyle())
                .help("Add Files or Folders")

                TextField(store.composerPlaceholder, text: $store.draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(Typography.interface(15, .medium))
                    .lineLimit(1...5)
                    .frame(minHeight: 30, alignment: .center)
                    .padding(.top, 1)
                    .focused($isFocused)
                    .onSubmit {
                        store.sendDraft()
                    }
                    .disabled(!store.canCompose)

                Button {
                    store.showModels()
                } label: {
                    ConsoleSymbolView(asset: .models, size: 15)
                }
                .buttonStyle(ComposerIconButtonStyle())
                .help("Models")

                Button {
                    store.sendDraft()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 13, weight: .bold))
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .buttonStyle(SendButtonStyle(isEnabled: store.canSendDraft))
                .disabled(!store.canSendDraft)
                .help("Send")
            }
            .padding(9)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isFocused ? Color.primary.opacity(0.78) : Theme.separator.opacity(0.75),
                        lineWidth: isFocused ? 1.25 : 1
                    )
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .background(.bar)
    }
}

private struct ComposerIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(isEnabled ? (configuration.isPressed ? Color.primary : Theme.secondaryText) : Theme.tertiaryText.opacity(0.55))
            .frame(width: 30, height: 30)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(configuration.isPressed ? Theme.subtleFill : Color.clear)
            }
    }
}

private struct SendButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var environmentIsEnabled
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        let resolvedIsEnabled = isEnabled && environmentIsEnabled

        configuration.label
            .foregroundStyle(Color(nsColor: .windowBackgroundColor))
            .frame(width: 28, height: 28)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(resolvedIsEnabled ? Color.primary.opacity(configuration.isPressed ? 0.7 : 1) : Theme.tertiaryText.opacity(0.45))
            }
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}
