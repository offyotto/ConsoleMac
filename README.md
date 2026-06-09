# ConsoleMac

ConsoleMac is a personal macOS coding assistant app built with SwiftUI and Swift Package Manager. It supports local MLX models, hosted OpenRouter/OpenAI API modes, local file tools, transcript export, conversation cleanup, and optional stdio MCP tools such as GitHub.

## Highlights

- Native macOS SwiftUI app with sidebar conversations, temporary chat, settings, and model management.
- Local model support through MLX Swift packages.
- Hosted API mode for OpenRouter and OpenAI with API keys stored in macOS Keychain.
- Local file search/read/write tools with user-controlled settings.
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
