import Foundation

enum SidebarSelection: Hashable {
    case conversations
    case temporaryChat
    case models
    case conversation(UUID)
}
