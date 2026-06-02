import Foundation
import Hypercode

/// A minimal Language Server Protocol server over stdio (JSON-RPC 2.0).
///
/// Capabilities: document lifecycle, live diagnostics (HC-101),
/// completion (HC-103) and hover (HC-103).
final class LSPServer {
    private var documents: [String: String] = [:]   // uri -> text
    private var buffer = Data()

    func run() {
        while let message = readMessage() {
            handle(message)
        }
    }

    // MARK: - Dispatch

    private func handle(_ message: [String: Any]) {
        let method = message["method"] as? String
        let id = message["id"]

        switch method {
        case "initialize":
            respond(id: id, result: [
                "capabilities": [
                    "textDocumentSync": ["openClose": true, "change": 1, "save": true],
                    "completionProvider": [
                        "triggerCharacters": [".", "#"],
                        "resolveProvider": false,
                    ],
                    "hoverProvider": true,
                ],
                "serverInfo": ["name": "hypercode", "version": "0.4.0"],
            ])
        case "initialized":
            break
        case "textDocument/didOpen":
            if let document = (message["params"] as? [String: Any])?["textDocument"] as? [String: Any],
               let uri = document["uri"] as? String,
               let text = document["text"] as? String {
                documents[uri] = text
                publishDiagnostics(uri: uri, text: text)
            }
        case "textDocument/didChange":
            if let params = message["params"] as? [String: Any],
               let uri = (params["textDocument"] as? [String: Any])?["uri"] as? String,
               let changes = params["contentChanges"] as? [[String: Any]],
               let text = changes.last?["text"] as? String {
                documents[uri] = text
                publishDiagnostics(uri: uri, text: text)
            }
        case "textDocument/didSave":
            if let uri = ((message["params"] as? [String: Any])?["textDocument"] as? [String: Any])?["uri"] as? String,
               let text = documents[uri] {
                publishDiagnostics(uri: uri, text: text)
            }
        case "textDocument/didClose":
            if let uri = ((message["params"] as? [String: Any])?["textDocument"] as? [String: Any])?["uri"] as? String {
                documents[uri] = nil
                send(["jsonrpc": "2.0", "method": "textDocument/publishDiagnostics",
                      "params": ["uri": uri, "diagnostics": []]])
            }
        case "textDocument/completion":
            if let params = message["params"] as? [String: Any],
               let uri = (params["textDocument"] as? [String: Any])?["uri"] as? String,
               let pos = params["position"] as? [String: Any],
               let line = pos["line"] as? Int,
               let char = pos["character"] as? Int,
               let text = documents[uri] {
                respond(id: id, result: completionItems(uri: uri, text: text, line: line, char: char))
            } else {
                respond(id: id, result: [])
            }
        case "textDocument/hover":
            if let params = message["params"] as? [String: Any],
               let uri = (params["textDocument"] as? [String: Any])?["uri"] as? String,
               let pos = params["position"] as? [String: Any],
               let line = pos["line"] as? Int,
               let char = pos["character"] as? Int,
               let text = documents[uri] {
                if let hover = hoverResult(uri: uri, text: text, line: line, char: char) {
                    respond(id: id, result: hover)
                } else {
                    respond(id: id, result: NSNull())
                }
            } else {
                respond(id: id, result: NSNull())
            }
        case "shutdown":
            respond(id: id, result: NSNull())
        case "exit":
            exit(0)
        default:
            if let id { respond(id: id, result: NSNull()) }
        }
    }

    // MARK: - Diagnostics

    private func publishDiagnostics(uri: String, text: String) {
        let computed = Hypercode.diagnostics(for: DocumentKind(path: uri), text: text).map(Self.lspObject)
        send(["jsonrpc": "2.0", "method": "textDocument/publishDiagnostics",
              "params": ["uri": uri, "diagnostics": computed]])
    }

    static func lspObject(_ d: Diagnostic) -> [String: Any] {
        let range = d.range ?? SourceRange(SourcePosition(line: 1, column: 1))
        return [
            "range": [
                "start": ["line": range.start.line - 1, "character": range.start.column - 1],
                "end": ["line": range.end.line - 1, "character": range.end.column - 1],
            ],
            "severity": d.severity.rawValue,
            "code": d.code,
            "source": "hypercode",
            "message": d.message,
        ]
    }

    // MARK: - Completion

    /// Returns completion items for the cursor position.
    /// - After `.`: class names used in this document.
    /// - After `#`: id names used in this document.
    /// - Otherwise: type names (command identifiers) from the current indent level.
    private func completionItems(uri: String, text: String, line: Int, char: Int, ) -> [[String: Any]] {
        guard DocumentKind(path: uri) == .hypercode else { return [] }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let currentLine = line < lines.count ? lines[line] : ""
        let prefix = char > 0 ? String(currentLine.prefix(char)) : ""

        guard let forest = try? Parser(source: text).parse() else { return [] }
        var types: [String] = []
        var classes: [String] = []
        var ids: [String] = []
        collectNames(forest, types: &types, classes: &classes, ids: &ids)

        // Choose what to complete based on the character just typed.
        if prefix.hasSuffix(".") {
            return classes.map { item($0, kind: 18, detail: "class") }   // 18 = Reference
        } else if prefix.hasSuffix("#") {
            return ids.map { item($0, kind: 6, detail: "id") }           // 6 = Variable
        } else {
            return types.map { item($0, kind: 7, detail: "command") }    // 7 = Class
        }
    }

    private func item(_ label: String, kind: Int, detail: String) -> [String: Any] {
        ["label": label, "kind": kind, "detail": detail]
    }

    private func collectNames(_ nodes: [Command], types: inout [String], classes: inout [String], ids: inout [String]) {
        for node in nodes {
            if !types.contains(node.type) { types.append(node.type) }
            if let c = node.className, !classes.contains(c) { classes.append(c) }
            if let i = node.id, !ids.contains(i) { ids.append(i) }
            collectNames(node.children, types: &types, classes: &classes, ids: &ids)
        }
    }

    // MARK: - Hover

    /// Returns Markdown hover content for the node at (line, char).
    private func hoverResult(uri: String, text: String, line: Int, char: Int) -> [String: Any]? {
        guard DocumentKind(path: uri) == .hypercode,
              let forest = try? Parser(source: text).parse(),
              let node = findNode(forest, atLine: line + 1)  // LSP 0-based → 1-based
        else { return nil }

        var md = "**`\(node.type)`**"
        if let c = node.className { md += "  \nclass: `.\(c)`" }
        if let i = node.id { md += "  \nid: `#\(i)`" }
        if !node.children.isEmpty { md += "  \n\(node.children.count) child(ren)" }

        return [
            "contents": ["kind": "markdown", "value": md],
            "range": [
                "start": ["line": line, "character": 0],
                "end": ["line": line, "character": 1000],
            ],
        ]
    }

    /// Finds the deepest node whose source line matches (1-based).
    private func findNode(_ nodes: [Command], atLine line: Int) -> Command? {
        for node in nodes {
            if let found = findNode(node.children, atLine: line) { return found }
            if node.line == line { return node }
        }
        return nil
    }

    // MARK: - JSON-RPC framing (Content-Length over stdio)

    private func respond(id: Any?, result: Any) {
        var message: [String: Any] = ["jsonrpc": "2.0", "result": result]
        if let id { message["id"] = id }
        send(message)
    }

    private func send(_ object: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: object) else { return }
        var out = Data("Content-Length: \(data.count)\r\n\r\n".utf8)
        out.append(data)
        FileHandle.standardOutput.write(out)
    }

    private func readMessage() -> [String: Any]? {
        while true {
            if let body = nextBody() {
                if let object = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] {
                    return object
                }
                continue
            }
            let chunk = FileHandle.standardInput.availableData
            if chunk.isEmpty { return nil }
            buffer.append(chunk)
        }
    }

    private func nextBody() -> Data? {
        guard let headerRange = buffer.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let header = String(decoding: buffer[buffer.startIndex..<headerRange.lowerBound], as: UTF8.self)
        var contentLength = 0
        for line in header.split(whereSeparator: { $0 == "\r" || $0 == "\n" }) {
            if line.lowercased().hasPrefix("content-length:") {
                contentLength = Int(line.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)) ?? 0
            }
        }
        let bodyStart = headerRange.upperBound
        guard buffer.distance(from: bodyStart, to: buffer.endIndex) >= contentLength else { return nil }
        let bodyEnd = buffer.index(bodyStart, offsetBy: contentLength)
        let body = Data(buffer[bodyStart..<bodyEnd])
        buffer = Data(buffer[bodyEnd...])
        return body
    }
}
