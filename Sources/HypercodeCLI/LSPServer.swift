import Foundation
import Hypercode

/// A minimal Language Server Protocol server over stdio (JSON-RPC 2.0).
///
/// Scope (HC-101): document lifecycle + live diagnostics. On open/change/save it
/// parses (`.hc`) or reads (`.hcs`) the document text and publishes diagnostics.
/// Hover / go-to-definition come later, on the same server.
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
                "capabilities": ["textDocumentSync": 1],   // 1 = Full
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
        case "shutdown":
            respond(id: id, result: NSNull())
        case "exit":
            exit(0)
        default:
            break
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
                continue // malformed frame; skip
            }
            let chunk = FileHandle.standardInput.availableData
            if chunk.isEmpty { return nil } // EOF
            buffer.append(chunk)
        }
    }

    /// Extracts one complete message body from the buffer, or `nil` if more
    /// input is needed.
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
        buffer = Data(buffer[bodyEnd...])   // re-base the remaining buffer
        return body
    }
}
