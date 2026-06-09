# ConsoleMac

ConsoleMac is a personal macOS coding assistant app built with SwiftUI and Swift Package Manager. It supports local MLX models, hosted OpenRouter / OpenAI API modes, local file tools, transcript export, conversation cleanup, and optional stdio MCP tools such as GitHub.

This branch contains a major **UI / UX & polish pass** on top of the original personal build. The agent loop, tool surface, MLX integration and storage formats are unchanged — everything new is additive.

## What's new in the polish pass

### ✨ Interaction

- **⌘K Command Palette** — spotlight-style switcher with keyboard navigation, fuzzy filter over commands, models, and recent conversations.
- **⌘/ Keyboard Shortcuts cheat sheet** — clean, grouped reference with kbd-style key caps.
- **⌘. Stop generating** — the send button morphs into a Stop button while the model is thinking, with a matching menu shortcut.
- **Conversation search** in the sidebar with live filtering across titles and message bodies.
- **Pin / Rename / Delete** conversations from context menus, with inline rename and confirmation alerts.
- **Drag-and-drop** files or folders onto the composer to add them as search resources, with animated drop target.
- **Attachment chips** for current search resources, removable inline.
- **Toast notifications** for copy / export / pin / delete confirmations.
- **Quick prompt suggestions** on the home screen and on empty conversation threads — tap to seed the composer.
- **Time-of-day greeting** and recent conversations preview on the home screen.

### 🎨 Visuals

- New centralized `Theme` with semantic colors, radii, spacing and motion tokens; consistent corner radii and elevation across the app.
- Gradient accent system on the send button, brand mark and avatars, with soft shadows.
- Hover highlights everywhere (sidebar rows, palette rows, buttons, message actions).
- Refined code blocks: window-style traffic-light header, language pill, line count, **line numbers**, and a copy button that confirms in place.
- Smooth message-row reveal animations, day dividers as pills, and a relaxed timestamp that reveals on hover.
- Streaming "Thinking" pill now uses the accent gradient and a softer wave.
- Status pill in the top bar pulses while the model is generating.
- Onboarding now has spring-animated step transitions, a progress bar, and ⌘← / ⌘→ shortcuts.
- Ambient gradient backdrop on the home view.

### ⌨️ Keyboard

| Action | Shortcut |
|---|---|
| New conversation | `⌘N` |
| Send message | `⌘↩` |
| Stop generating | `⌘.` |
| Quick switch | `⌘K` |
| Show shortcuts | `⌘/` |
| Copy conversation | `⇧⌘C` |
| Export transcript | `⇧⌘E` |
| Add search files | `⇧⌘O` |
| Settings | `⌘,` |

## Original highlights

- Native macOS SwiftUI app with sidebar conversations, temporary chat, settings, and model management.
- Local model support through MLX Swift packages.
- Hosted API mode for OpenRouter and OpenAI with API keys stored in macOS Keychain.
- Local file search / read / write tools with user-controlled settings.
- Token-safe agent loop protections: capped tool output, capped MCP tool exposure, and local input-budget checks before sending oversized API requests.
- OpenRouter provider-failure handling with readable errors and fallback routing.

## Requirements

- macOS 14 or newer
- Xcode command line tools
- Swift 6.1 toolchain
- Optional: Docker and GitHub CLI for the bundled GitHub MCP server command

## Build And Run

```sh
swift build
./script/build_and_run.sh
```

The build script stages a local app bundle at:

```text
dist/Console.app
```

Useful checks:

```sh
./script/build_and_run.sh --verify
codesign --verify --deep --strict --verbose=4 dist/Console.app
```

## Packaging

To copy a runnable app and zip into `~/Downloads`:

```sh
PACKAGE_STAMP=LocalBuild ./script/build_and_run.sh --package
```

## API Keys

ConsoleMac stores OpenRouter and OpenAI keys in macOS Keychain. Keys are not stored in this repository or in UserDefaults.

## MCP

The app includes settings for stdio MCP servers. The default personal build can restore a GitHub Docker MCP command, but MCP tools are only exposed to the model when the user prompt looks relevant to GitHub or external tooling, and the exposed tool list is capped.

## Notes

This is a personal build, not an App Store sandboxed build. macOS privacy prompts and Full Disk Access settings still apply when using local file search or file tools.

## File-by-file changes

| File | Status | Notes |
|---|---|---|
| `Support/Theme.swift` | rewritten | Adds Radius / Spacing / Motion tokens and gradients. |
| `Support/ToastCenter.swift` | **new** | App-wide toast notification system. |
| `Support/HoverEffect.swift` | **new** | `.hoverHighlight()` modifier + `PressableButtonStyle`. |
| `Stores/ConsoleStore+Enhancements.swift` | **new** | Pin / rename / delete / stop additions (extension only). |
| `Views/SidebarView.swift` | rewritten | Search, pin, rename, delete, hover, badges. |
| `Views/ComposerView.swift` | rewritten | Stop button, char counter, drop target, hint row. |
| `Views/MessageRow.swift` | rewritten | Hover actions, code block with line numbers + copy toast, timestamp. |
| `Views/MessagesView.swift` | rewritten | Suggestion chips, animated empty state. |
| `Views/TopBarView.swift` | rewritten | Status pill, ⌘K button, more menu w/ pin/delete. |
| `Views/ConversationDetailView.swift` | updated | New bindings for palette + shortcuts sheet. |
| `Views/ContentView.swift` | rewritten | Hosts toast / palette overlays, new home view. |
| `Views/CommandPaletteView.swift` | **new** | ⌘K spotlight-style palette. |
| `Views/KeyboardShortcutsView.swift` | **new** | ⌘/ cheat sheet. |
| `Views/OnboardingView.swift` | updated | Animated step transitions + progress bar. |
| `App/ConsoleMacApp.swift` | updated | Adds Stop (⌘.) command. |
