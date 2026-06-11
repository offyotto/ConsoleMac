import SwiftUI

@MainActor
final class ToastCenter: ObservableObject {
    static let shared = ToastCenter()

    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let icon: String
        let title: String
    }

    @Published private(set) var current: Toast?
    private var dismissTask: Task<Void, Never>?

    func show(_ title: String, icon: String = "checkmark.circle.fill") {
        let toast = Toast(icon: icon, title: title)
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            current = toast
        }
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_700_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    self?.current = nil
                }
            }
        }
    }
}

struct ToastOverlay: View {
    @ObservedObject private var center = ToastCenter.shared

    var body: some View {
        VStack {
            Spacer()
            if let toast = center.current {
                HStack(spacing: 9) {
                    Image(systemName: toast.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    Text(toast.title)
                        .font(Typography.interface(12.5, .medium))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().stroke(Theme.separator.opacity(0.6), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 6)
                .padding(.bottom, 26)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity.combined(with: .scale(scale: 0.96))
                ))
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .allowsHitTesting(false)
    }
}
