import Foundation

enum AgentToolService {
    static func toolDefinitions(preferences: AppPreferences) -> [[String: Any]] {
        guard preferences.apiLocalFileToolsEnabled else { return [] }

        var tools: [[String: Any]] = [
            functionTool(
                name: "search_local_files",
                description: "Search readable local text files for context relevant to a query.",
                properties: [
                    "query": [
                        "type": "string",
                        "description": "The search query or key terms."
                    ]
                ],
                required: ["query"]
            ),
            functionTool(
                name: "read_local_file",
                description: "Read a local UTF-8 text file by absolute path or ~/ path.",
                properties: [
                    "path": [
                        "type": "string",
                        "description": "Absolute path or ~/ path to a text file."
                    ]
                ],
                required: ["path"]
            ),
            functionTool(
                name: "list_directory",
                description: "List files and folders inside a local directory.",
                properties: [
                    "path": [
                        "type": "string",
                        "description": "Absolute path or ~/ path to a directory."
                    ]
                ],
                required: ["path"]
            ),
            functionTool(
                name: "current_datetime",
                description: "Get the current local date, time, and timezone.",
                properties: [:],
                required: []
            )
        ]

        if preferences.apiFileWriteToolsEnabled {
            tools.append(
                functionTool(
                    name: "write_local_file",
                    description: "Write a UTF-8 text file. Use only when the user clearly asks to create or update a file.",
                    properties: [
                        "path": [
                            "type": "string",
                            "description": "Absolute path or ~/ path to write."
                        ],
                        "content": [
                            "type": "string",
                            "description": "The full text content to write."
                        ],
                        "overwrite": [
                            "type": "boolean",
                            "description": "Whether an existing file may be overwritten."
                        ],
                        "create_directories": [
                            "type": "boolean",
                            "description": "Whether to create parent directories if missing."
                        ]
                    ],
                    required: ["path", "content", "overwrite", "create_directories"]
                )
            )

            tools.append(
                functionTool(
                    name: "create_directory",
                    description: "Create a local directory and any missing parent directories.",
                    properties: [
                        "path": [
                            "type": "string",
                            "description": "Absolute path or ~/ path to create."
                        ]
                    ],
                    required: ["path"]
                )
            )
        }

        return tools
    }

    static func execute(
        name: String,
        argumentsJSON: String,
        preferences: AppPreferences
    ) -> String {
        do {
            let arguments = try decodeArguments(argumentsJSON)

            switch name {
            case "search_local_files":
                return jsonResult([
                    "ok": true,
                    "context": FileSearchService.context(
                        for: string("query", in: arguments),
                        preferences: preferences
                    )
                ])
            case "read_local_file":
                return try readLocalFile(path: string("path", in: arguments))
            case "list_directory":
                return try listDirectory(path: string("path", in: arguments))
            case "write_local_file":
                guard preferences.apiFileWriteToolsEnabled else {
                    return jsonResult(["ok": false, "error": "File write tools are disabled in Console settings."])
                }
                return try writeLocalFile(
                    path: string("path", in: arguments),
                    content: string("content", in: arguments),
                    overwrite: bool("overwrite", in: arguments),
                    createDirectories: bool("create_directories", in: arguments)
                )
            case "create_directory":
                guard preferences.apiFileWriteToolsEnabled else {
                    return jsonResult(["ok": false, "error": "File write tools are disabled in Console settings."])
                }
                return try createDirectory(path: string("path", in: arguments))
            case "current_datetime":
                return jsonResult([
                    "ok": true,
                    "date": Date().formatted(date: .complete, time: .complete),
                    "timezone": TimeZone.current.identifier
                ])
            default:
                return jsonResult(["ok": false, "error": "Unknown tool: \(name)"])
            }
        } catch {
            return jsonResult(["ok": false, "error": error.localizedDescription])
        }
    }

    private static func functionTool(
        name: String,
        description: String,
        properties: [String: Any],
        required: [String]
    ) -> [String: Any] {
        [
            "type": "function",
            "name": name,
            "description": description,
            "strict": true,
            "parameters": [
                "type": "object",
                "properties": properties,
                "required": required,
                "additionalProperties": false
            ]
        ]
    }

    private static func decodeArguments(_ argumentsJSON: String) throws -> [String: Any] {
        guard let data = argumentsJSON.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return object
    }

    private static func readLocalFile(path: String) throws -> String {
        let url = resolvedURL(from: path)
        guard !isProtectedSystemPath(url) else {
            return jsonResult(["ok": false, "error": "Refusing to read protected system path: \(url.path)"])
        }

        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true else {
            return jsonResult(["ok": false, "error": "Not a regular file: \(url.path)"])
        }

        let fileSize = values.fileSize ?? 0
        guard fileSize <= 700_000 else {
            return jsonResult(["ok": false, "error": "File is too large to read in one tool call: \(url.path)"])
        }

        let contents = try String(contentsOf: url, encoding: .utf8)
        let content = AgentBudget.truncated(contents, limit: AgentBudget.maximumLocalFileCharacters)
        return jsonResult([
            "ok": true,
            "path": url.path,
            "content": content,
            "truncated": contents.count > content.count
        ])
    }

    private static func listDirectory(path: String) throws -> String {
        let url = resolvedURL(from: path)
        guard !isProtectedSystemPath(url) else {
            return jsonResult(["ok": false, "error": "Refusing to list protected system path: \(url.path)"])
        }

        let values = try url.resourceValues(forKeys: [.isDirectoryKey])
        guard values.isDirectory == true else {
            return jsonResult(["ok": false, "error": "Not a directory: \(url.path)"])
        }

        let urls = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )

        let entries = try urls
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .prefix(60)
            .map { child -> [String: Any] in
                let values = try child.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
                return [
                    "name": child.lastPathComponent,
                    "path": child.path,
                    "is_directory": values.isDirectory == true,
                    "size": values.fileSize ?? 0
                ]
            }

        return jsonResult([
            "ok": true,
            "path": url.path,
            "entries": entries,
            "truncated": urls.count > entries.count
        ])
    }

    private static func writeLocalFile(
        path: String,
        content: String,
        overwrite: Bool,
        createDirectories: Bool
    ) throws -> String {
        let url = resolvedURL(from: path)
        guard !isProtectedSystemPath(url) else {
            return jsonResult(["ok": false, "error": "Refusing to write protected system path: \(url.path)"])
        }

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: url.path), overwrite == false {
            return jsonResult(["ok": false, "error": "File already exists and overwrite is false: \(url.path)"])
        }

        if createDirectories {
            try fileManager.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        }

        try content.write(to: url, atomically: true, encoding: .utf8)
        return jsonResult([
            "ok": true,
            "path": url.path,
            "bytes": Data(content.utf8).count
        ])
    }

    private static func createDirectory(path: String) throws -> String {
        let url = resolvedURL(from: path)
        guard !isProtectedSystemPath(url) else {
            return jsonResult(["ok": false, "error": "Refusing to create protected system path: \(url.path)"])
        }

        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return jsonResult(["ok": true, "path": url.path])
    }

    private static func string(_ key: String, in arguments: [String: Any]) -> String {
        (arguments[key] as? String) ?? ""
    }

    private static func bool(_ key: String, in arguments: [String: Any]) -> Bool {
        (arguments[key] as? Bool) ?? false
    }

    private static func resolvedURL(from path: String) -> URL {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedPath == "~" {
            return FileManager.default.homeDirectoryForCurrentUser
        }

        if trimmedPath.hasPrefix("~/") {
            let relativePath = String(trimmedPath.dropFirst(2))
            return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(relativePath)
                .standardizedFileURL
        }

        return URL(fileURLWithPath: trimmedPath).standardizedFileURL
    }

    private static func isProtectedSystemPath(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let protectedPrefixes = [
            "/System",
            "/bin",
            "/sbin",
            "/usr/bin",
            "/usr/sbin"
        ]

        return protectedPrefixes.contains { prefix in
            path == prefix || path.hasPrefix(prefix + "/")
        }
    }

    private static func jsonResult(_ object: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "{\"ok\":false,\"error\":\"Tool returned an invalid JSON result.\"}"
        }

        return string
    }
}
