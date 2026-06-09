import SwiftUI
import UniformTypeIdentifiers

struct ComposerView: View {
    @ObservedObject var store: ConsoleStore
    @FocusState private var isFocused: Bool
    @State private var isDropTargeted: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            attachmentsStrip

            HStack(alignment: .center, spacing: 10) {
                Menu {
                    Button {
                        store.addSearchResourcesFromOpenPanel()
                    } label: {
                        Label("Add Files or Folders…", systemImage: "folder.badge.plus")
                    }
                    Button {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    } label: {
                        Label("Manage Search Resources…", systemImage: "slider.horizontal.3")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                } primaryAction: {
                    store.addSearchResourcesFromOpenPanel()
                }
                .menuStyle(.button)
                .buttonStyle(ComposerIconButtonStyle())
                .menuIndicator(.hidden)
                .help("Add Files or Folders")
                .fixedSize()

                TextField(store.composerPlaceholder, text: $store.draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(Typography.interface(15, .medium))
                    .lineLimit(1...8)
                    .frame(minHeight: 30, alignment: .center)
                    .padding(.top, 1)
                    .focused($isFocused)
                    .onSubmit(handleSubmit)
                    .disabled(!store.canCompose)

                if !store.draft.isEmpty {
                    Text("\(store.draft.count)")
                        .font(Typography.interface(10, .semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.subtleFill))
                        .transition(.opacity.combined(with: .scale))
                }

                Button {
                    store.showModels()
                } label: {
                    ConsoleSymbolView(asset: .models, size: 15)
                }
                .buttonStyle(ComposerIconButtonStyle())
                .help("Models")

                sendOrStopButton
            }
            .padding(9)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(borderColor, lineWidth: isFocused || isDropTargeted ? 1.5 : 1)
                    .animation(Theme.Motion.hover, value: isFocused)
                    .animation(Theme.Motion.hover, value: isDropTargeted)
            }
            .shadow(color: Color.black.opacity(isFocused ? 0.06 : 0), radius: 8, x: 0, y: 2)
            .animation(.easeOut(duration: 0.18), value: store.draft.isEmpty)
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                handleFileDrop(providers: providers)
            }

            footerHint
        }
        .padding(.horizontal, 28)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(.bar)
    }

    private var borderColor: Color {
        if isDropTargeted { return Theme.accent }
        if isFocused { return Color.primary.opacity(0.78) }
        return Theme.separator.opacity(0.75)
    }

    private func handleSubmit() {
        // Plain Return inserts a newline (axis: .vertical handles that automatically);
        // Cmd+Return is wired below via .keyboardShortcut.
        store.sendDraft()
    }

    @ViewBuilder
    private var sendOrStopButton: some View {
        if store.isGeneratingResponse {
            Button {
                store.requestStopGeneration()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 12, weight: .bold))
            }
            .buttonStyle(StopButtonStyle())
            .help("Stop")
            .transition(.scale(scale: 0.85).combined(with: .opacity))
        } else {
            Button {
                store.sendDraft()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 13, weight: .bold))
            }
            .keyboardShortcut(.return, modifiers: [.command])
            .buttonStyle(SendButtonStyle(isEnabled: store.canSendDraft))
            .disabled(!store.canSendDraft)
            .help("Send (⌘↩)")
            .transition(.scale(scale: 0.85).combined(with: .opacity))
        }
    }

    // MARK: - Attachments strip

    @ViewBuilder
    private var attachmentsStrip: some View {
        let resources = store.preferences.searchResources
        if !resources.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(resources) { resource in
                        AttachmentChip(resource: resource) {
                            store.removeSearchResource(resource.id)
                            ToastCenter.shared.show("Removed resource", icon: "trash")
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(height: 26)
            .padding(.bottom, 2)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Hint row

    private var footerHint: some View {
        HStack(spacing: 6) {
            Image(systemName: store.canCompose ? "checkmark.circle.fill" : "exclamationmark.circle")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(store.canCompose ? Theme.accent : .secondary)
            Text(hintText)
                .font(Typography.interface(10.5, .medium))
                .foregroundStyle(.secondary)
            Spacer()
            if store.canCompose && !store.isGeneratingResponse {
                Text("⌘↩ Send  ·  ⇧↩ New line  ·  ⌘K Quick switch")
                    .font(Typography.interface(10).monospacedDigit())
                    .foregroundStyle(.secondary.opacity(0.85))
            } else if store.isGeneratingResponse {
                StreamingPulse()
                Text("Generating…")
                    .font(Typography.interface(10.5, .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
    }

    private var hintText: String {
        if isDropTargeted { return "Drop to add as a search resource" }
        if store.isGeneratingResponse { return "Press Stop to interrupt the response" }
        if !store.canCompose {
            return store.preferences.apiAgentModeEnabled
                ? "Add an API key in Settings to enable sending"
                : "Install a model from the Models tab"
        }
        return store.preferences.apiAgentModeEnabled
            ? "API agent mode · \(store.preferences.apiProvider.title)"
            : "Local model · ready"
    }

    // MARK: - Drag-and-drop

    private func handleFileDrop(providers: [NSItemProvider]) -> Bool {
        var didLoadAny = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                didLoadAny = true
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    Task { @MainActor in
                        var isDirectory: ObjCBool = false
                        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
                        guard exists else { return }
                        let bookmark = SearchResourceBookmark(
                            displayName: url.lastPathComponent,
                            lastKnownPath: url.path,
                            isDirectory: isDirectory.boolValue,
                            bookmarkData: try? url.bookmarkData(options: .withSecurityScope)
                        )
                        store.updatePreferences { prefs in
                            let known = Set(prefs.searchResources.map(\.lastKnownPath))
                            if !known.contains(bookmark.lastKnownPath) {
                                prefs.searchResources.append(bookmark)
                            }
                        }
                        ToastCenter.shared.show("Added \(bookmark.displayName)", icon: "paperclip")
                    }
                }
            }
        }
        return didLoadAny
    }
}

// MARK: - Attachment chip

private struct AttachmentChip: View {
    let resource: SearchResourceBookmark
    let remove: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: resource.isDirectory ? "folder.fill" : "doc.text.fill")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(resource.displayName)
                .font(Typography.interface(11, .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
            if hovering {
                Button(action: remove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Theme.subtleFill))
        .overlay(Capsule().stroke(Theme.separator.opacity(0.4), lineWidth: 0.5))
        .onHover { hovering = $0 }
        .help(resource.lastKnownPath)
        .animation(Theme.Motion.hover, value: hovering)
    }
}

// MARK: - Streaming pulse

private struct StreamingPulse: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let scale = 0.78 + (sin(t * 4.6) + 1) / 2 * 0.32
            Circle()
                .fill(Theme.accent)
                .frame(width: 6, height: 6)
                .scaleEffect(scale)
                .opacity(0.65 + (sin(t * 4.6) + 1) / 2 * 0.3)
        }
        .frame(width: 8, height: 8)
    }
}

// MARK: - Button styles

private struct ComposerIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(foreground(isPressed: configuration.isPressed))
            .frame(width: 30, height: 30)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(fillStyle(isPressed: configuration.isPressed))
                    .animation(Theme.Motion.hover, value: hovering)
            }
            .onHover { hovering = $0 }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(Theme.Motion.snap, value: configuration.isPressed)
    }

    private func foreground(isPressed: Bool) -> Color {
        if !isEnabled { return Theme.tertiaryText.opacity(0.55) }
        return isPressed ? Color.primary : Theme.secondaryText
    }

    private func fillStyle(isPressed: Bool) -> Color {
        if isPressed { return Theme.subtleFill }
        return hovering ? Theme.hoverFill : Color.clear
    }
}

private struct SendButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var environmentIsEnabled
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        let resolvedIsEnabled = isEnabled && environmentIsEnabled

        configuration.label
            .foregroundStyle(Color(nsColor: .windowBackgroundColor))
            .frame(width: 30, height: 30)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        resolvedIsEnabled
                            ? AnyShapeStyle(Theme.accentGradient)
                            : AnyShapeStyle(Theme.tertiaryText.opacity(0.45))
                    )
            }
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .shadow(color: resolvedIsEnabled ? Theme.accent.opacity(0.35) : .clear,
                    radius: configuration.isPressed ? 2 : 6,
                    x: 0, y: configuration.isPressed ? 1 : 3)
            .animation(Theme.Motion.snap, value: configuration.isPressed)
    }
}

private struct StopButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.red.opacity(configuration.isPressed ? 0.7 : 0.9))
            }
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .shadow(color: Color.red.opacity(0.35), radius: 5, x: 0, y: 2)
            .animation(Theme.Motion.snap, value: configuration.isPressed)
    }
}
