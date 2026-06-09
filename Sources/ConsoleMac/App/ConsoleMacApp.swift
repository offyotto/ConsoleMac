import AppKit
import SwiftUI

@main
struct ConsoleMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ConsoleStore()

    var body: some Scene {
        WindowGroup("Console", id: "main") {
            ContentView(store: store)
                .frame(minWidth: 920, minHeight: 640)
                .preferredColorScheme(nil)
        }
        .defaultSize(width: 1080, height: 740)
        .commands {
            ConsoleCommands(store: store)
        }

        Settings {
            ConsoleSettingsView(store: store)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct ConsoleCommands: Commands {
    let store: ConsoleStore

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Conversation") {
                store.createConversation()
            }
            .keyboardShortcut("n", modifiers: [.command])

            Button("Command Palette…") {
                store.requestCommandPalette()
            }
            .keyboardShortcut("k", modifiers: [.command])
        }

        CommandMenu("Conversation") {
            Button("Send Message") {
                store.sendDraft()
            }
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(!store.canSendDraft)

            Button("Stop Generating") {
                store.requestStopGeneration()
            }
            .keyboardShortcut(".", modifiers: [.command])
            .disabled(!store.isGeneratingResponse)

            Divider()

            Button("Copy Conversation") {
                store.copySelectedConversation()
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(!store.canExportSelectedConversation)

            Button("Export Transcript…") {
                store.exportSelectedConversation()
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(!store.canExportSelectedConversation)

            Divider()

            Button("Add Search Files…") {
                store.addSearchResourcesFromOpenPanel()
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .help) {
            Button("ConsoleMac Help") {
                if let url = URL(string: "https://github.com/") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}
