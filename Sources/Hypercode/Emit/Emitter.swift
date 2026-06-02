/// Output format for the canonical resolved-graph IR.
public enum EmitFormat: String, Sendable {
    case json
    case yaml
}

/// Serializes a resolved graph into a canonical, schema-agnostic IR
/// (`hypercode.ir/v1`). This output is a generated artifact, not a source —
/// `.hc` + `.hcs` remain the source of truth.
public struct Emitter {
    public init() {}

    public func emit(_ forest: [ResolvedNode], as format: EmitFormat) -> String {
        let root = Emitter.intermediate(forest)
        switch format {
        case .json: return Emitter.json(root, indent: 0) + "\n"
        case .yaml: return Emitter.yaml(root)
        }
    }

    // MARK: - Canonical intermediate representation

    indirect enum IR {
        case string(String)
        case int(Int)
        case array([IR])
        case object([(String, IR)]) // ordered keys
    }

    static func intermediate(_ forest: [ResolvedNode]) -> IR {
        .object([
            ("version", .string("hypercode.ir/v1")),
            ("nodes", .array(forest.map(node))),
        ])
    }

    private static func node(_ node: ResolvedNode) -> IR {
        var fields: [(String, IR)] = [("type", .string(node.type))]
        if let className = node.className { fields.append(("class", .string(className))) }
        if let id = node.id { fields.append(("id", .string(id))) }

        let properties = node.properties.keys.sorted().map { key -> (String, IR) in
            let resolved = node.properties[key]!
            return (key, .object([
                ("value", .string(resolved.value)),
                ("from", .string(resolved.provenance.selector.description)),
                ("line", .int(resolved.provenance.line)),
            ]))
        }
        fields.append(("properties", .object(properties)))
        fields.append(("children", .array(node.children.map(self.node))))
        return .object(fields)
    }

    // MARK: - JSON

    static func json(_ value: IR, indent: Int) -> String {
        let pad = String(repeating: "  ", count: indent)
        let inner = String(repeating: "  ", count: indent + 1)
        switch value {
        case let .string(string):
            return "\"\(escape(string))\""
        case let .int(number):
            return String(number)
        case let .array(items):
            if items.isEmpty { return "[]" }
            let body = items.map { inner + json($0, indent: indent + 1) }.joined(separator: ",\n")
            return "[\n\(body)\n\(pad)]"
        case let .object(pairs):
            if pairs.isEmpty { return "{}" }
            let body = pairs
                .map { inner + "\"\($0.0)\": " + json($0.1, indent: indent + 1) }
                .joined(separator: ",\n")
            return "{\n\(body)\n\(pad)}"
        }
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
                    let digits = Array("0123456789abcdef")
                    out += "\\u00\(digits[Int((scalar.value >> 4) & 0xF)])\(digits[Int(scalar.value & 0xF)])"
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        return out
    }

    // MARK: - YAML

    static func yaml(_ value: IR) -> String {
        guard case let .object(pairs) = value else { return yamlScalar(value) + "\n" }
        return pairs.map { yamlPair($0.0, $0.1, indent: 0) }.joined()
    }

    private static func yamlPair(_ key: String, _ value: IR, indent: Int) -> String {
        let pad = String(repeating: "  ", count: indent)
        switch value {
        case .string, .int:
            return "\(pad)\(key): \(yamlScalar(value))\n"
        case let .array(items):
            if items.isEmpty { return "\(pad)\(key): []\n" }
            return "\(pad)\(key):\n" + items.map { arrayItem($0, indent: indent + 1) }.joined()
        case let .object(pairs):
            if pairs.isEmpty { return "\(pad)\(key): {}\n" }
            return "\(pad)\(key):\n" + pairs.map { yamlPair($0.0, $0.1, indent: indent + 1) }.joined()
        }
    }

    private static func arrayItem(_ value: IR, indent: Int) -> String {
        let pad = String(repeating: "  ", count: indent)
        switch value {
        case let .object(pairs):
            if pairs.isEmpty { return "\(pad)- {}\n" }
            // A dash on its own line, then the mapping indented beneath it.
            return "\(pad)-\n" + pairs.map { yamlPair($0.0, $0.1, indent: indent + 1) }.joined()
        default:
            return "\(pad)- \(yamlScalar(value))\n"
        }
    }

    private static func yamlScalar(_ value: IR) -> String {
        switch value {
        case let .int(number): return String(number)
        case let .string(string): return needsQuoting(string) ? "\"\(escape(string))\"" : string
        default: return ""
        }
    }

    private static func needsQuoting(_ string: String) -> Bool {
        if string.isEmpty { return true }
        if let first = string.first, first == " " || first == "-" || first == "?" { return true }
        if let last = string.last, last == " " { return true }
        let special: Set<Character> = [
            ":", "#", "\"", "'", "{", "}", "[", "]", ",", "&", "*",
            "|", "<", ">", "=", "!", "%", "@", "`", "\\",
        ]
        if string.contains(where: { special.contains($0) }) { return true }
        if ["true", "false", "null", "yes", "no", "~"].contains(string.lowercased()) { return true }
        if Int(string) != nil || Double(string) != nil { return true }
        return false
    }
}
