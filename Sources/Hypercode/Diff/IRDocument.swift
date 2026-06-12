/// An error raised while interpreting a parsed JSON document as IR v2.
public struct IRError: Error, Equatable, CustomStringConvertible, Sendable {
    public let message: String

    public var description: String { "ir error: \(message)" }
}

/// One resolved property as read back from an IR v2 document: the typed value
/// and a human-readable description of the rule that won it.
public struct IRProperty: Equatable, Sendable {
    public let value: JSONValue
    /// "selector @ file:line" — where the winning value was written.
    public let winner: String

    public init(value: JSONValue, winner: String) {
        self.value = value
        self.winner = winner
    }
}

/// One node of an IR v2 document.
public struct IRNode: Equatable, Sendable {
    public let type: String
    public let className: String?
    public let id: String?
    public let hash: String
    public let properties: [String: IRProperty]
    public let children: [IRNode]

    public init(
        type: String, className: String? = nil, id: String? = nil,
        hash: String, properties: [String: IRProperty] = [:],
        children: [IRNode] = []
    ) {
        self.type = type
        self.className = className
        self.id = id
        self.hash = hash
        self.properties = properties
        self.children = children
    }

    /// Selector-style label: `type[.class][#id]` — the node's identity for
    /// matching across document versions.
    public var label: String {
        var text = type
        if let c = className { text += ".\(c)" }
        if let i = id { text += "#\(i)" }
        return text
    }
}

/// A `hypercode.ir/v2` document read back from JSON, carrying just what the
/// differ needs: hashes, typed values, winner provenance, and the tree shape.
public struct IRDocument: Equatable, Sendable {
    public let documentHash: String
    public let context: [String: String]
    public let nodes: [IRNode]

    public init(documentHash: String, context: [String: String] = [:], nodes: [IRNode]) {
        self.documentHash = documentHash
        self.context = context
        self.nodes = nodes
    }

    /// Interprets parsed JSON as an IR v2 document. Rejects other versions —
    /// v1 has no hashes, so it cannot be diffed structurally.
    public init(json: JSONValue) throws {
        guard case let .object(root) = json else {
            throw IRError(message: "expected a JSON object at the top level")
        }
        guard case let .string(version)? = root["version"] else {
            throw IRError(message: "missing 'version'")
        }
        guard version == "hypercode.ir/v2" else {
            throw IRError(message: "diff requires hypercode.ir/v2 (got '\(version)'); re-emit with --ir-version 2")
        }
        guard case let .string(documentHash)? = root["documentHash"] else {
            throw IRError(message: "missing 'documentHash'")
        }
        var context: [String: String] = [:]
        if case let .object(ctx)? = root["context"] {
            for (key, value) in ctx {
                if case let .string(s) = value { context[key] = s }
            }
        }
        guard case let .array(nodes)? = root["nodes"] else {
            throw IRError(message: "missing 'nodes'")
        }
        self.documentHash = documentHash
        self.context = context
        self.nodes = try nodes.map { try IRDocument.node($0) }
    }

    private static func node(_ json: JSONValue) throws -> IRNode {
        guard case let .object(fields) = json else {
            throw IRError(message: "node is not an object")
        }
        guard case let .string(type)? = fields["type"] else {
            throw IRError(message: "node missing 'type'")
        }
        guard case let .string(hash)? = fields["hash"] else {
            throw IRError(message: "node '\(type)' missing 'hash'")
        }
        var className: String?
        if case let .string(c)? = fields["class"] { className = c }
        var id: String?
        if case let .string(i)? = fields["id"] { id = i }

        var properties: [String: IRProperty] = [:]
        if case let .object(props)? = fields["properties"] {
            for (key, entry) in props {
                guard case let .object(prop) = entry, let value = prop["value"] else {
                    throw IRError(message: "property '\(key)' missing 'value'")
                }
                properties[key] = IRProperty(value: value, winner: winner(prop["winner"]))
            }
        }

        var children: [IRNode] = []
        if case let .array(kids)? = fields["children"] {
            children = try kids.map { try node($0) }
        }
        return IRNode(
            type: type, className: className, id: id,
            hash: hash, properties: properties, children: children
        )
    }

    private static func winner(_ json: JSONValue?) -> String {
        guard case let .object(w)? = json, case let .string(selector)? = w["selector"] else {
            return "?"
        }
        var line = "?"
        if case let .number(n)? = w["line"] { line = n }
        if case let .string(file)? = w["file"] {
            return "\(selector) @ \(file):\(line)"
        }
        return "\(selector) @ line \(line)"
    }
}
