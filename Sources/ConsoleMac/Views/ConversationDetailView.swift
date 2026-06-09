import SwiftUI

struct ConversationDetailView: View {
    @ObservedObject var store: ConsoleStore

    var body: some View {
        VStack(spacing: 0) {
            TopBarView(store: store)

            Divider()

            if store.selectedConversation != nil {
                MessagesView(store: store)
            } else {
                EmptyConversationView()
            }

            ComposerView(store: store)
        }
        .background(Theme.windowBackground)
    }
}

private struct EmptyConversationView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "text.bubble")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.secondary)
            Text("No conversation selected")
                .font(Typography.interface(16, .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
