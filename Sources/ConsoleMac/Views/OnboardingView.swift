import SwiftUI

struct OnboardingView: View {
    @ObservedObject var store: ConsoleStore
    @State private var preferences: AppPreferences
    @State private var step: OnboardingStep = .identity

    init(store: ConsoleStore) {
        self.store = store
        _preferences = State(initialValue: store.preferences)
    }

    private var canContinue: Bool {
        !preferences.userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !preferences.assistantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(spacing: 0) {
                Group {
                    switch step {
                    case .identity:
                        IdentityStep(preferences: $preferences)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    case .preferences:
                        PreferenceStep(preferences: $preferences)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    case .instructions:
                        InstructionsStep(preferences: $preferences)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(28)
                .animation(.spring(response: 0.42, dampingFraction: 0.86), value: step)

                Divider()

                footer
            }
            .frame(width: 520, height: 500)
            .background(Theme.windowBackground)
        }
        .frame(width: 720, height: 500)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(Theme.subtleFill)
                        .frame(width: 34, height: 34)
                    TerminalIconView(size: 20)
                        .foregroundStyle(.primary)
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text("Console")
                        .font(Typography.interface(16, .bold))
                    Text("Setup")
                        .font(Typography.interface(11))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.subtleFill).frame(height: 4)
                        Capsule()
                            .fill(Theme.accentGradient)
                            .frame(width: progressWidth(in: proxy.size.width), height: 4)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: step)
                    }
                }
                .frame(height: 4)
                Text("Step \(step.rawValue + 1) of \(OnboardingStep.allCases.count)")
                    .font(Typography.interface(10, .semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(OnboardingStep.allCases) { item in
                    OnboardingStepRow(
                        step: item,
                        isSelected: item == step,
                        isComplete: item.rawValue < step.rawValue
                    )
                    .onTapGesture {
                        if item.rawValue <= step.rawValue || canContinue {
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                                step = item
                            }
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(22)
        .frame(width: 200)
        .frame(maxHeight: .infinity, alignment: .leading)
        .background(.regularMaterial)
    }

    private var footer: some View {
        HStack {
            Button("Back") {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                    step = OnboardingStep(rawValue: step.rawValue - 1) ?? .identity
                }
            }
            .disabled(step == .identity)
            .keyboardShortcut(.leftArrow, modifiers: [.command])

            Spacer()

            if step == .instructions {
                Button {
                    store.completeOnboarding(preferences)
                } label: {
                    Label("Get Started", systemImage: "checkmark")
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canContinue)
                .keyboardShortcut(.return, modifiers: [.command])
            } else {
                Button {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                        step = OnboardingStep(rawValue: step.rawValue + 1) ?? .instructions
                    }
                } label: {
                    Label("Continue", systemImage: "arrow.right")
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canContinue)
                .keyboardShortcut(.return, modifiers: [.command])
            }
        }
        .padding(.horizontal, 24)
        .frame(height: 62)
        .background(.bar)
    }

    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        let total = max(1, OnboardingStep.allCases.count - 1)
        let fraction = CGFloat(step.rawValue) / CGFloat(total)
        return max(20, totalWidth * fraction)
    }
}

private enum OnboardingStep: Int, CaseIterable, Identifiable {
    case identity
    case preferences
    case instructions

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .identity: return "Identity"
        case .preferences: return "Preferences"
        case .instructions: return "Instructions"
        }
    }

    var systemImage: String {
        switch self {
        case .identity: return "person.crop.circle"
        case .preferences: return "slider.horizontal.3"
        case .instructions: return "text.alignleft"
        }
    }
}

private struct OnboardingStepRow: View {
    let step: OnboardingStep
    let isSelected: Bool
    let isComplete: Bool

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : step.systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(width: 18)

            Text(step.title)
                .font(Typography.interface(13, isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? .primary : .secondary)

            Spacer()
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(isSelected ? Theme.subtleFill : Color.clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct IdentityStep: View {
    @Binding var preferences: AppPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            StepTitle(
                title: "Set up your names",
                subtitle: "Used in transcripts and when building model prompts."
            )

            VStack(alignment: .leading, spacing: 14) {
                LabeledField(
                    title: "What should the model call you?",
                    text: $preferences.userName,
                    prompt: "Your name"
                )

                LabeledField(
                    title: "What should the model call itself?",
                    text: $preferences.assistantName,
                    prompt: "Console"
                )
            }
        }
    }
}

private struct PreferenceStep: View {
    @Binding var preferences: AppPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            StepTitle(
                title: "Defaults",
                subtitle: "These apply when preparing requests for local models."
            )

            VStack(alignment: .leading, spacing: 16) {
                Picker("Response style", selection: $preferences.responsePreference) {
                    ForEach(ResponsePreference.allCases) { preference in
                        Text(preference.title).tag(preference)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Keep code context with new prompts", isOn: $preferences.keepCodeContext)
                Toggle("Save transcripts on this Mac", isOn: $preferences.saveTranscripts)
                Toggle("Use full Mac file access for agent search", isOn: $preferences.fullFileSystemAccessEnabled)
            }
            .font(Typography.interface(13))
        }
    }
}

private struct InstructionsStep: View {
    @Binding var preferences: AppPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            StepTitle(
                title: "Custom instructions",
                subtitle: "Standing behavior for local models to follow."
            )

            ZStack(alignment: .topLeading) {
                TextEditor(text: $preferences.customInstructions)
                    .font(Typography.interface(13))
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(Theme.textBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Theme.separator.opacity(0.75), lineWidth: 1)
                    }

                if preferences.customInstructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("e.g. mirror my casual tone, keep coding answers concrete, ask before destructive operations.")
                        .font(Typography.interface(13))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 220)
        }
    }
}

private struct StepTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Typography.interface(24, .semibold))
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(Typography.interface(13))
                .foregroundStyle(.secondary)
        }
    }
}

private struct LabeledField: View {
    let title: String
    @Binding var text: String
    let prompt: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(Typography.interface(12, .semibold))
                .foregroundStyle(.secondary)

            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(Typography.interface(15, .medium))
                .padding(.horizontal, 11)
                .frame(height: 36)
                .background(Theme.textBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Theme.separator.opacity(0.75), lineWidth: 1)
                }
        }
    }
}
