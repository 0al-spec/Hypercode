/// Output format for the canonical resolved-graph IR.
public enum EmitFormat: String, Sendable {
    case json
    case yaml
}

/// IR schema version to emit.
public enum EmitVersion: String, Sendable {
    case v1 = "1"
    case v2 = "2"
}

/// Serializes a resolved graph into a canonical, schema-agnostic IR.
/// v1 = `hypercode.ir/v1` (string values, selector + line provenance).
/// v2 = `hypercode.ir/v2` (typed values, winner/losers, per-node SHA-256 hashes, context echo).
/// This output is a generated artifact, not a source — `.hc` + `.hcs` remain the source of truth.
public struct Emitter {
    public init() {}

    public func emit(
        _ forest: [ResolvedNode],
        version: EmitVersion = .v2,
        context: ResolutionContext = [:],
        commands: [Command] = [],
        contracts: [SelectorContract] = [],
        as format: EmitFormat
    ) -> String {
        let root: IR
        switch version {
        case .v1: root = Emitter.intermediateV1(forest)
        case .v2: root = Emitter.intermediateV2(
            forest, context: context, commands: commands, contracts: contracts
        )
        }
        switch format {
        case .json: return Emitter.json(root, indent: 0) + "\n"
        case .yaml: return Emitter.yaml(root)
        }
    }

    /// Legacy overload — emits v1 (preserved for existing callers).
    public func emit(_ forest: [ResolvedNode], as format: EmitFormat) -> String {
        emit(forest, version: .v1, as: format)
    }

    // MARK: - Canonical intermediate representation

    indirect enum IR {
        case string(String)
        case int(Int)
        case double(Double)
        case bool(Bool)
        case null
        case array([IR])
        case object([(String, IR)]) // ordered keys
    }

    // MARK: v1

    static func intermediateV1(_ forest: [ResolvedNode]) -> IR {
        .object([
            ("version", .string("hypercode.ir/v1")),
            ("nodes", .array(forest.map(nodeV1))),
        ])
    }

    // Legacy entry point used by EmitterTests and the legacy emit() overload.
    static func intermediate(_ forest: [ResolvedNode]) -> IR { intermediateV1(forest) }

    private static func nodeV1(_ node: ResolvedNode) -> IR {
        var fields: [(String, IR)] = [("type", .string(node.type))]
        if let className = node.className { fields.append(("class", .string(className))) }
        if let id = node.id { fields.append(("id", .string(id))) }

        let properties = node.properties.keys.sorted().map { key -> (String, IR) in
            let resolved = node.properties[key]!
            return (key, .object([
                ("value", .string(resolved.value.rawString)),
                ("from", .string(resolved.provenance.selector.description)),
                ("line", .int(resolved.provenance.line)),
            ]))
        }
        fields.append(("properties", .object(properties)))
        fields.append(("children", .array(node.children.map(self.nodeV1))))
        return .object(fields)
    }

    // MARK: v2

    static func intermediateV2(
        _ forest: [ResolvedNode],
        context: ResolutionContext,
        commands: [Command] = [],
        contracts: [SelectorContract] = []
    ) -> IR {
        let hashes = forest.map { nodeHash($0) }
        let nodeIRs = zip(forest, commands.isEmpty ? Array(repeating: nil, count: forest.count) as [Command?] : commands.map(Optional.init))
            .map { node, cmd in nodeV2(node, command: cmd, ancestors: [], contracts: contracts) }
        let docHash = documentHash(hashes)
        return .object([
            ("version", .string("hypercode.ir/v2")),
            ("context", .object(context.keys.sorted().map { ($0, .string(context[$0]!)) })),
            ("resolver", .object([
                ("name", .string("hypercode-swift")),
                ("version", .string("0.5.0")),
            ])),
            ("documentHash", .string(docHash)),
            ("nodes", .array(zip(nodeIRs, hashes).map { nodeIR, hash in
                guard case var .object(pairs) = nodeIR else { return nodeIR }
                let insertAt = pairs.firstIndex(where: { $0.0 == "properties" }) ?? pairs.endIndex
                pairs.insert(("hash", .string(hash)), at: insertAt)
                return .object(pairs)
            })),
        ])
    }

    private static func nodeV2(
        _ node: ResolvedNode,
        command: Command?,
        ancestors: [Command],
        contracts: [SelectorContract]
    ) -> IR {
        var fields: [(String, IR)] = [("type", .string(node.type))]
        if let className = node.className { fields.append(("class", .string(className))) }
        if let id = node.id { fields.append(("id", .string(id))) }

        let properties = node.properties.keys.sorted().map { key -> (String, IR) in
            let rv = node.properties[key]!
            let applicableContracts = command.map { cmd -> [IR] in
                let ctx = NodeContext(node: cmd, ancestors: ancestors)
                return contracts
                    .filter { sc in selectorSpec(sc.selector).isSatisfiedBy(ctx) }
                    .compactMap { sc -> IR? in
                        guard let pc = sc.properties[key] else { return nil }
                        return contractIR(pc, selector: sc.selector)
                    }
            } ?? []
            let propFields: [(String, IR)] = [
                ("value", typedValueIR(rv.value)),
                ("winner", matchIR(rv.winner)),
                ("losers", .array(rv.losers.map(matchIR))),
                ("contracts", .array(applicableContracts)),
            ]
            return (key, .object(propFields))
        }
        fields.append(("properties", .object(properties)))

        let childCommands = command.map { $0.children } ?? []
        let childAncs = command.map { ancestors + [$0] } ?? ancestors
        fields.append(("children", .array(zip(node.children, childCommands.isEmpty
            ? Array(repeating: nil, count: node.children.count) as [Command?]
            : childCommands.map(Optional.init)).map { child, childCmd in
            nodeV2(child, command: childCmd, ancestors: childAncs, contracts: contracts)
        })))
        return .object(fields)
    }

    private static func contractIR(_ pc: PropertyContract, selector: Selector) -> IR {
        var pairs: [(String, IR)] = [
            ("selector", .string(selector.description)),
            ("type", .string(pc.type.rawValue)),
            ("required", .bool(pc.required)),
        ]
        if let min = pc.min { pairs.append(("min", .double(min))) }
        if let max = pc.max { pairs.append(("max", .double(max))) }
        return .object(pairs)
    }

    private static func typedValueIR(_ v: TypedValue) -> IR {
        switch v {
        case .string(let s): return .string(s)
        case .int(let i):    return .int(i)
        case .double(let d): return .double(d)
        case .bool(let b):   return .bool(b)
        }
    }

    private static func matchIR(_ m: Match) -> IR {
        var pairs: [(String, IR)] = [
            ("selector", .string(m.selector.description)),
            ("specificity", .array([
                .int(m.specificity.ids),
                .int(m.specificity.classes),
                .int(m.specificity.types),
            ])),
            ("order", .int(m.order)),
            ("line", .int(m.line)),
        ]
        if let f = m.file { pairs.append(("file", .string(f))) }
        pairs.append(("value", typedValueIR(m.value)))
        return .object(pairs)
    }

    // MARK: Hashing

    /// Computes a SHA-256 hash over the stable resolved content of a node:
    /// type, class?, id?, resolved property values (not provenance), and child hashes.
    /// Changing a winning value or the tree structure changes the hash;
    /// changing which rule won (with the same value) does not.
    private static func nodeHash(_ node: ResolvedNode) -> String {
        let childHashes = node.children.map { nodeHash($0) }
        let stableProps = node.properties.keys.sorted().map { key -> (String, IR) in
            (key, typedValueIR(node.properties[key]!.value))
        }
        var fields: [(String, IR)] = [("type", .string(node.type))]
        if let c = node.className { fields.append(("class", .string(c))) }
        if let i = node.id { fields.append(("id", .string(i))) }
        fields.append(("properties", .object(stableProps)))
        fields.append(("children", .array(childHashes.map { .string($0) })))
        return SHA256.hash(utf8: json(.object(fields), indent: 0)).hexString
    }

    private static func documentHash(_ nodeHashes: [String]) -> String {
        SHA256.hash(utf8: nodeHashes.joined(separator: "\n")).hexString
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
        case let .double(number):
            // Emit without trailing ".0" when it's a whole number.
            return number.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(number)) + ".0"
                : String(number)
        case let .bool(flag):
            return flag ? "true" : "false"
        case .null:
            return "null"
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
        case .string, .int, .double, .bool, .null:
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
        case let .double(d): return String(d)
        case let .bool(b): return b ? "true" : "false"
        case .null: return "null"
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
