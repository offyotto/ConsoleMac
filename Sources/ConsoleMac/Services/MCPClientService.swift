import Foundation

enum MCPClientError: LocalizedError {
    case launchFailed(String)
    case timeout(String)
    case invalidResponse
    case serverError(String)
    case toolNotFound(String)

    var errorDescription: String? {
        switch self {
        case .launchFailed(let command):
            return "Could not launch MCP server: \(command)"
        case .timeout(let operation):
            return "Timed out waiting for MCP \(operation)."
        case .invalidResponse:
            return "The MCP server returned an invalid response."
        case .serverError(let message):
            return "MCP server error: \(message)"
        case .toolNotFound(let name):
            return "MCP tool not found: \(name)"
        }
    }
}

enum MCPClientService {
    static func discoverTools(from servers: [MCPServerConfig]) -> MCPToolContext {
        let context = MCPToolContext()

        for server in servers where server.isEnabled {
            do {
                let session = try MCPStdioSession(server: server)
                let tools = try session.listTools()
                context.add(session: session, server: server, tools: tools)
            } catch {
                context.addDiscoveryError(server: server, error: error)
            }
        }

        return context
    }
}

final class MCPToolContext {
    private var sessions: [UUID: MCPStdioSession] = [:]
    private var toolMap: [String: MCPToolMapping] = [:]
    private(set) var discoveryErrors: [String] = []

    var hasTools: Bool {
        toolMap.isEmpty == false
    }

    func add(session: MCPStdioSession, server: MCPServerConfig, tools: [MCPTool]) {
        sessions[server.id] = session

        for tool in tools {
            let exposedName = uniqueToolName(for: server, tool: tool)
            toolMap[exposedName] = MCPToolMapping(
                exposedName: exposedName,
                serverID: server.id,
                serverName: server.name,
                originalName: tool.name,
                description: tool.description ?? tool.title ?? "MCP tool \(tool.name)",
                inputSchema: tool.inputSchema
            )
        }
    }

    func addDiscoveryError(server: MCPServerConfig, error: Error) {
        discoveryErrors.append("\(server.name): \(error.localizedDescription)")
    }

    func chatToolDefinitions(matching query: String, limit: Int = AgentBudget.maximumMCPToolDefinitions) -> [[String: Any]] {
        let rankedTools = toolMap.values
            .map { mapping in (mapping: mapping, score: relevanceScore(for: mapping, query: query)) }
            .filter { $0.score > 0 }
            .sorted {
                if $0.score == $1.score {
                    return $0.mapping.exposedName < $1.mapping.exposedName
                }
                return $0.score > $1.score
            }
            .prefix(limit)

        return rankedTools
            .map(\.mapping)
            .map { mapping in
                [
                    "type": "function",
                    "function": [
                        "name": mapping.exposedName,
                        "description": "[\(mapping.serverName)] \(mapping.description)",
                        "parameters": mapping.inputSchema
                    ]
                ]
            }
    }

    func call(exposedName: String, argumentsJSON: String) -> String {
        guard let mapping = toolMap[exposedName] else {
            return jsonResult(["ok": false, "error": MCPClientError.toolNotFound(exposedName).localizedDescription])
        }

        guard let session = sessions[mapping.serverID] else {
            return jsonResult(["ok": false, "error": "MCP session is no longer available for \(mapping.serverName)."])
        }

        do {
            let arguments = try decodeJSONObject(argumentsJSON)
            let result = try session.callTool(name: mapping.originalName, arguments: arguments)
            let compactResult = AgentBudget.compactJSONString(result)
            return jsonResult([
                "ok": true,
                "server": mapping.serverName,
                "tool": mapping.originalName,
                "result": compactResult.text,
                "truncated": compactResult.truncated
            ])
        } catch {
            return jsonResult([
                "ok": false,
                "server": mapping.serverName,
                "tool": mapping.originalName,
                "error": error.localizedDescription
            ])
        }
    }

    func containsTool(named exposedName: String) -> Bool {
        toolMap[exposedName] != nil
    }

    func close() {
        sessions.values.forEach { $0.close() }
        sessions.removeAll()
        toolMap.removeAll()
    }

    private func uniqueToolName(for server: MCPServerConfig, tool: MCPTool) -> String {
        var baseName = "mcp__\(sanitize(server.name))__\(sanitize(tool.name))"
        if baseName.count > 64 {
            let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8)
            baseName = String(baseName.prefix(55)) + "_" + suffix
        }

        var candidate = baseName
        var index = 2
        while toolMap[candidate] != nil {
            let suffix = "_\(index)"
            candidate = String(baseName.prefix(max(1, 64 - suffix.count))) + suffix
            index += 1
        }

        return candidate
    }

    private func sanitize(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        let scalars = value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "_"
        }
        let sanitized = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "_-"))
        return sanitized.isEmpty ? "server" : sanitized
    }

    private func relevanceScore(for mapping: MCPToolMapping, query: String) -> Int {
        let terms = Self.queryTerms(from: query)
        let haystack = "\(mapping.exposedName) \(mapping.originalName) \(mapping.description)".lowercased()

        var score = 0
        for term in terms where haystack.contains(term) {
            score += mapping.originalName.lowercased().contains(term) ? 3 : 1
        }

        return score
    }

    private static func queryTerms(from query: String) -> [String] {
        let separators = CharacterSet.alphanumerics.inverted
        var terms = query
            .lowercased()
            .components(separatedBy: separators)
            .filter { $0.count >= 3 }

        if query.lowercased().contains("pull request") || query.lowercased().contains(" pr ") {
            terms.append(contentsOf: ["pull", "request"])
        }

        if query.lowercased().contains("repo") {
            terms.append("repository")
        }

        return Array(Set(terms))
    }
}

final class MCPStdioSession: @unchecked Sendable {
    private let server: MCPServerConfig
    private let process = Process()
    private let stdinPipe = Pipe()
    private let stdoutPipe = Pipe()
    private let stderrPipe = Pipe()
    private let lock = NSLock()
    private let lineSemaphore = DispatchSemaphore(value: 0)
    private var lineBuffer = Data()
    private var lines: [String] = []
    private var nextID = 1
    private var isClosed = false

    init(server: MCPServerConfig) throws {
        self.server = server

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", server.endpoint]
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            self?.appendOutput(handle.availableData)
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData
        }

        do {
            try process.run()
        } catch {
            close()
            throw MCPClientError.launchFailed(server.endpoint)
        }

        try initialize()
    }

    func listTools() throws -> [MCPTool] {
        var allTools: [MCPTool] = []
        var cursor: String?

        repeat {
            var params: [String: Any] = [:]
            if let cursor {
                params["cursor"] = cursor
            }

            let response = try sendRequest(method: "tools/list", params: params.isEmpty ? nil : params)
            guard let result = response["result"] as? [String: Any],
                  let toolObjects = result["tools"] as? [[String: Any]] else {
                throw MCPClientError.invalidResponse
            }

            allTools.append(contentsOf: toolObjects.compactMap(MCPTool.init(json:)))
            cursor = result["nextCursor"] as? String
        } while cursor != nil

        return allTools
    }

    func callTool(name: String, arguments: [String: Any]) throws -> [String: Any] {
        let response = try sendRequest(
            method: "tools/call",
            params: [
                "name": name,
                "arguments": arguments
            ],
            timeout: 45
        )

        guard let result = response["result"] as? [String: Any] else {
            throw MCPClientError.invalidResponse
        }

        return result
    }

    func close() {
        lock.lock()
        let alreadyClosed = isClosed
        isClosed = true
        lock.unlock()

        guard alreadyClosed == false else { return }

        // Clean up file handles gracefully — failures here are non-fatal.
        // The process will be terminated regardless of cleanup success.
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil
        
        do {
            try stdinPipe.fileHandleForWriting.close()
        } catch {
            // Non-fatal: pipe may already be closed or broken.
            // Process termination will clean up resources.
        }

        if process.isRunning {
            process.terminate()
        }
    }

    private func initialize() throws {
        _ = try sendRequest(
            method: "initialize",
            params: [
                "protocolVersion": "2025-06-18",
                "capabilities": [
                    "tools": [:]
                ],
                "clientInfo": [
                    "name": "Console",
                    "version": "1.0"
                ]
            ],
            timeout: 20
        )

        try sendNotification(method: "notifications/initialized", params: [:])
    }

    private func sendRequest(
        method: String,
        params: [String: Any]? = nil,
        timeout: TimeInterval = 20
    ) throws -> [String: Any] {
        let id = nextRequestID()
        var request: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "method": method
        ]
        if let params {
            request["params"] = params
        }

        try writeMessage(request)
        return try readResponse(id: id, operation: method, timeout: timeout)
    }

    private func sendNotification(method: String, params: [String: Any]) throws {
        try writeMessage([
            "jsonrpc": "2.0",
            "method": method,
            "params": params
        ])
    }

    private func nextRequestID() -> Int {
        lock.lock()
        defer { lock.unlock() }
        let id = nextID
        nextID += 1
        return id
    }

    private func writeMessage(_ message: [String: Any]) throws {
        guard JSONSerialization.isValidJSONObject(message) else {
            throw MCPClientError.invalidResponse
        }

        var data = try JSONSerialization.data(withJSONObject: message)
        data.append(0x0A)
        stdinPipe.fileHandleForWriting.write(data)
    }

    private func readResponse(id: Int, operation: String, timeout: TimeInterval) throws -> [String: Any] {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if let line = popLine() {
                guard let data = line.data(using: .utf8),
                      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    continue
                }

                guard let responseID = object["id"] as? Int, responseID == id else {
                    continue
                }

                if let error = object["error"] as? [String: Any] {
                    let message = error["message"] as? String ?? "Unknown MCP error"
                    throw MCPClientError.serverError(message)
                }

                return object
            }

            let remaining = max(0.05, deadline.timeIntervalSinceNow)
            _ = lineSemaphore.wait(timeout: .now() + min(0.25, remaining))
        }

        throw MCPClientError.timeout(operation)
    }

    private func appendOutput(_ data: Data) {
        guard data.isEmpty == false else { return }

        lock.lock()
        lineBuffer.append(data)

        while let newlineIndex = lineBuffer.firstIndex(of: 0x0A) {
            let lineData = lineBuffer[..<newlineIndex]
            lineBuffer.removeSubrange(...newlineIndex)

            if let line = String(data: lineData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               line.isEmpty == false {
                lines.append(line)
                lineSemaphore.signal()
            }
        }
        lock.unlock()
    }

    private func popLine() -> String? {
        lock.lock()
        defer { lock.unlock() }

        guard lines.isEmpty == false else { return nil }
        return lines.removeFirst()
    }

    deinit {
        close()
    }
}

struct MCPTool {
    var name: String
    var title: String?
    var description: String?
    var inputSchema: [String: Any]

    init?(json: [String: Any]) {
        guard let name = json["name"] as? String else { return nil }
        self.name = name
        title = json["title"] as? String
        description = json["description"] as? String

        if let schema = json["inputSchema"] as? [String: Any] {
            inputSchema = MCPTool.normalizedSchema(schema)
        } else {
            inputSchema = [
                "type": "object",
                "properties": [:],
                "additionalProperties": false
            ]
        }
    }

    private static func normalizedSchema(_ schema: [String: Any]) -> [String: Any] {
        var normalized = schema
        if normalized["type"] == nil {
            normalized["type"] = "object"
        }
        if normalized["properties"] == nil {
            normalized["properties"] = [:]
        }
        return normalized
    }
}

private struct MCPToolMapping {
    var exposedName: String
    var serverID: UUID
    var serverName: String
    var originalName: String
    var description: String
    var inputSchema: [String: Any]
}

private func decodeJSONObject(_ json: String) throws -> [String: Any] {
    guard let data = json.data(using: .utf8),
          let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return [:]
    }
    return object
}

private func jsonResult(_ object: [String: Any]) -> String {
    guard JSONSerialization.isValidJSONObject(object),
          let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
          let string = String(data: data, encoding: .utf8) else {
        return "{\"ok\":false,\"error\":\"Tool returned an invalid JSON result.\"}"
    }

    return string
}
