/// Output format for diagnostics.
public enum DiagnosticFormat: String, Sendable {
    case text
    case json
}

public extension Severity {
    /// Short label used in human-readable output.
    var label: String {
        switch self {
        case .error: return "error"
        case .warning: return "warning"
        case .information: return "note"
        case .hint: return "hint"
        }
    }
}

public extension Diagnostic {
    /// A single editor-parseable line: `file:line:col: error[HC1101]: message`.
    func renderedText() -> String {
        var location = ""
        if let file { location += "\(file):" }
        if let range {
            location += "\(range.start.line):\(range.start.column): "
        } else if !location.isEmpty {
            location += " "
        }
        return "\(location)\(severity.label)[\(code)]: \(message)"
    }
}

/// Renders diagnostics for the CLI and tools.
public enum DiagnosticsRenderer {
    public static func render(_ diagnostics: [Diagnostic], as format: DiagnosticFormat) -> String {
        switch format {
        case .text:
            return diagnostics.map { $0.renderedText() }.joined(separator: "\n")
        case .json:
            return "[" + diagnostics.map(lspObject).joined(separator: ",") + "]"
        }
    }

    /// One diagnostic as an LSP-shaped JSON object (positions are 0-based, per LSP).
    private static func lspObject(_ d: Diagnostic) -> String {
        var fields: [String] = []
        if let range = d.range {
            let start = "{\"line\":\(range.start.line - 1),\"character\":\(range.start.column - 1)}"
            let end = "{\"line\":\(range.end.line - 1),\"character\":\(range.end.column - 1)}"
            fields.append("\"range\":{\"start\":\(start),\"end\":\(end)}")
        }
        fields.append("\"severity\":\(d.severity.rawValue)")
        fields.append("\"code\":\"\(escape(d.code))\"")
        fields.append("\"source\":\"hypercode\"")
        fields.append("\"message\":\"\(escape(d.message))\"")
        if let file = d.file {
            fields.append("\"file\":\"\(escape(file))\"")
        }
        return "{" + fields.joined(separator: ",") + "}"
    }

    private static func escape(_ string: String) -> String {
        var out = ""
        for scalar in string.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\t": out += "\\t"
            case "\r": out += "\\r"
            default:
                if scalar.value < 0x20 {
                    let hex = Array("0123456789abcdef")
                    out += "\\u00\(hex[Int((scalar.value >> 4) & 0xF)])\(hex[Int(scalar.value & 0xF)])"
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        return out
    }
}
