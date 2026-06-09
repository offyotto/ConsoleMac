# Console Personal Build

Console is currently packaged as a personal macOS app, not an App Store build.

## What This Means

- The staged app is ad-hoc signed by default.
- No App Sandbox entitlement is applied.
- Agent file search can use normal local filesystem paths.
- macOS privacy controls still apply. If you want Console to read protected locations without prompts, add it to Full Disk Access in System Settings.
- API agent mode stores provider API keys in macOS Keychain, not UserDefaults.
- OpenRouter agent mode uses `https://openrouter.ai/api/v1/chat/completions`, the `web` plugin, local function tools, and stdio MCP tools.
- OpenAI agent mode uses the Responses API with web search and local function tools.
- GitHub MCP is seeded with the official Docker server command:

```sh
docker run -i --rm -e GITHUB_PERSONAL_ACCESS_TOKEN -e GITHUB_TOOLSETS=all ghcr.io/github/github-mcp-server
```

Set `GITHUB_PERSONAL_ACCESS_TOKEN` in your shell or Docker environment before using the server.

## Local Checks

```sh
swift build
./script/build_and_run.sh --verify
codesign --verify --deep --strict --verbose=4 dist/Console.app
codesign -d --entitlements :- dist/Console.app
```

The entitlements check should not show `com.apple.security.app-sandbox`.
