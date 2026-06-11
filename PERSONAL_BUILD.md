# Personal Build

ConsoleMac is packaged as a personal macOS app, not an App Store build.

## What this means

- Ad-hoc signed by default
- No App Sandbox entitlement
- Agent file search uses normal local filesystem paths
- macOS privacy controls still apply. For Full Disk Access without prompts, add Console to System Settings
- API keys stored in macOS Keychain, not UserDefaults
- OpenRouter uses `https://openrouter.ai/api/v1/chat/completions` with the `web` plugin, local function tools, and stdio MCP tools
- OpenAI uses the Responses API with web search and local function tools
- GitHub MCP is seeded with the official Docker server command:

```sh
docker run -i --rm -e GITHUB_PERSONAL_ACCESS_TOKEN -e GITHUB_TOOLSETS=all ghcr.io/github/github-mcp-server
```

Set `GITHUB_PERSONAL_ACCESS_TOKEN` in your shell or Docker environment before using the server.

## Local checks

```sh
swift build
./script/build_and_run.sh --verify
codesign --verify --deep --strict --verbose=4 dist/Console.app
codesign -d --entitlements :- dist/Console.app
```

The entitlements check should not show `com.apple.security.app-sandbox`.
