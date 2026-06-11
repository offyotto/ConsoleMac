# ConsoleMac

A macOS coding assistant built with SwiftUI and Swift Package Manager. Supports local MLX models, OpenRouter and OpenAI API modes, local file tools, transcript export, conversation management, and stdio MCP tools.

## Requirements

- macOS 14 or later
- Xcode command line tools
- Swift 6.1 toolchain
- Optional: Docker and GitHub CLI for the GitHub MCP server

## Build and run

```sh
swift build
./script/build_and_run.sh
```

The build script stages a local app bundle at `dist/Console.app`.

```sh
./script/build_and_run.sh --verify
codesign --verify --deep --strict --verbose=4 dist/Console.app
```

## Packaging

```sh
PACKAGE_STAMP=LocalBuild ./script/build_and_run.sh --package
```

## Features

- Native macOS SwiftUI app with sidebar conversations, temporary chat, settings, and model management
- Local model support via MLX Swift packages
- API mode for OpenRouter and OpenAI with keys stored in macOS Keychain
- Local file search, read, and write tools
- Token-safe agent loop: capped tool output, capped MCP tool exposure, local input-budget checks
- OpenRouter provider-failure handling with fallback routing
- Command palette (⌘K), keyboard shortcuts sheet (⌘/)
- Conversation search, pin, rename, and delete
- Drag-and-drop file attachments
- Toast notifications for confirmations
- Streaming responses with stop button (⌘.)

## Keyboard shortcuts

| Action | Shortcut |
|---|---|
| New conversation | ⌘N |
| Send message | ⌘↩ |
| Stop generating | ⌘. |
| Quick switch | ⌘K |
| Show shortcuts | ⌘/ |
| Copy conversation | ⇧⌘C |
| Export transcript | ⇧⌘E |
| Add search files | ⇧⌘O |
| Settings | ⌘, |

## API keys

OpenRouter and OpenAI keys are stored in macOS Keychain. They are not stored in this repository or in UserDefaults.

## MCP

The app supports stdio MCP servers. The default build includes a GitHub Docker MCP command. MCP tools are only exposed when the user prompt is relevant, and the exposed tool count is capped.

## Notes

This is a personal build, not an App Store sandboxed build. macOS privacy prompts and Full Disk Access settings apply when using local file search.

## Changed files

| File | Status | Notes |
|---|---|---|
| `Support/Theme.swift` | updated | Radius, spacing, and motion tokens |
| `Support/ToastCenter.swift` | new | App-wide toast notifications |
| `Support/HoverEffect.swift` | new | `.hoverHighlight()` modifier and `PressableButtonStyle` |
| `Stores/ConsoleStore+Enhancements.swift` | new | Pin, rename, delete, stop (extension only) |
| `Views/SidebarView.swift` | updated | Search, pin, rename, delete, hover, badges |
| `Views/ComposerView.swift` | updated | Stop button, char counter, drop target, hint row |
| `Views/MessageRow.swift` | updated | Hover actions, code block with line numbers and copy, timestamp |
| `Views/MessagesView.swift` | updated | Suggestion chips, animated empty state |
| `Views/TopBarView.swift` | updated | Status pill, ⌘K button, more menu |
| `Views/ConversationDetailView.swift` | updated | Bindings for palette and shortcuts sheet |
| `Views/ContentView.swift` | updated | Toast and palette overlays, home view |
| `Views/CommandPaletteView.swift` | new | ⌘K command palette |
| `Views/KeyboardShortcutsView.swift` | new | ⌘/ shortcuts sheet |
| `Views/OnboardingView.swift` | updated | Step transitions and progress bar |
| `App/ConsoleMacApp.swift` | updated | Stop (⌘.) command |
