/// An error raised while reading a `.hcs` cascade sheet.
public struct HCSError: Error, Equatable, CustomStringConvertible, Sendable {
    public let message: String
    public let line: Int

    public var description: String { "hcs error at line \(line): \(message)" }
}

/// A minimal, hand-rolled reader for the `.hcs` subset we use today: selector
/// headers, `@dimension[value]` context blocks, and `key: value` properties,
/// nested by indentation. No third-party YAML dependency — typed scalars and
/// full YAML come later, only if we ever consume real YAML input.
public struct CascadeSheetReader {
    public init() {}

    /// Parse a `.hcs` source string into a `CascadeSheet`.
    /// - Parameter file: Optional path of the source file, stored in each `Rule` for provenance.
    public func read(_ source: String, file: String? = nil) throws -> CascadeSheet {
        let lines: [RawLine] = source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .map { offset, element in
                var text = String(element)
                if text.hasSuffix("\r") { text.removeLast() }
                return RawLine(number: offset + 1, text: text)
            }
            // Skip blanks and YAML-style comment lines (id selectors are quoted,
            // e.g. '#main-db', so a bare leading '#' is always a comment).
            .filter { !$0.isBlank && !$0.trimmed.hasPrefix("#") }

        var index = 0
        let outline = buildOutline(lines, &index, parentIndent: -1)

        var rules: [Rule] = []
        var contracts: [SelectorContract] = []
        var order = 0
        for node in outline {
            try interpretTopLevel(node, file: file, into: &rules, contracts: &contracts, order: &order)
        }
        return CascadeSheet(rules: rules, contracts: contracts)
    }

    // MARK: - Outline (group lines into a tree by indentation)

    private struct Outline {
        let line: RawLine
        let children: [Outline]
    }

    private func buildOutline(_ lines: [RawLine], _ index: inout Int, parentIndent: Int) -> [Outline] {
        var nodes: [Outline] = []
        while index < lines.count {
            let indent = lines[index].indentation
            if indent <= parentIndent { break }
            let line = lines[index]
            index += 1
            let children = buildOutline(lines, &index, parentIndent: indent)
            nodes.append(Outline(line: line, children: children))
        }
        return nodes
    }

    // MARK: - Interpretation

    private func interpretTopLevel(
        _ node: Outline,
        file: String?,
        into rules: inout [Rule],
        contracts: inout [SelectorContract],
        order: inout Int
    ) throws {
        let content = String(node.line.trimmed)
        if content == "@contract:" {
            for child in node.children {
                try interpretContractSelector(child, file: file, into: &contracts)
            }
        } else if content.hasPrefix("@") {
            guard let split = splitFirstColon(content), split.right.isEmpty else {
                throw HCSError(message: "expected '@dimension[value]:'", line: node.line.number)
            }
            let condition = try parseGuard(String(split.left), line: node.line.number)
            for child in node.children {
                try interpretRule(child, condition: condition, file: file, into: &rules, order: &order)
            }
        } else {
            try interpretRule(node, condition: nil, file: file, into: &rules, order: &order)
        }
    }

    private func interpretContractSelector(_ node: Outline, file: String?, into contracts: inout [SelectorContract]) throws {
        let content = String(node.line.trimmed)
        guard let split = splitFirstColon(content), split.right.isEmpty else {
            throw HCSError(message: "expected a selector header ending with ':' in @contract block", line: node.line.number)
        }
        let selector = try parseSelector(String(split.left), line: node.line.number)
        var properties: [String: PropertyContract] = [:]
        for child in node.children {
            let (key, contract) = try parseConstraintLine(child)
            properties[key] = contract
        }
        contracts.append(SelectorContract(selector: selector, properties: properties, file: file, line: node.line.number))
    }

    private func parseConstraintLine(_ node: Outline) throws -> (String, PropertyContract) {
        guard node.children.isEmpty else {
            throw HCSError(message: "unexpected nested block in @contract constraint", line: node.line.number)
        }
        let content = String(node.line.trimmed)
        guard let colonIdx = content.firstIndex(of: ":") else {
            throw HCSError(message: "expected 'key[?]: type [>= n] [<= n]'", line: node.line.number)
        }
        var rawKey = String(trim(content[..<colonIdx]))
        let required: Bool
        if rawKey.hasSuffix("[?]") {
            required = false
            rawKey = String(rawKey.dropLast(3))
        } else {
            required = true
        }
        guard IdentifierSpec().isSatisfiedBy(rawKey) else {
            throw HCSError(message: "invalid constraint key '\(rawKey)'", line: node.line.number)
        }
        let rest = String(trim(content[content.index(after: colonIdx)...]))
        let (contractType, min, max) = try parseConstraintRHS(rest, line: node.line.number)
        return (rawKey, PropertyContract(type: contractType, required: required, min: min, max: max))
    }

    private func parseConstraintRHS(_ text: String, line: Int) throws -> (ContractType, Double?, Double?) {
        var tokens = text.split(separator: " ").map(String.init)
        guard !tokens.isEmpty else {
            throw HCSError(message: "expected type name in constraint", line: line)
        }
        let typeName = tokens.removeFirst()
        guard let contractType = ContractType(rawValue: typeName.lowercased()) else {
            throw HCSError(message: "unknown constraint type '\(typeName)'; expected string|int|float|bool", line: line)
        }
        var min: Double?
        var max: Double?
        var i = 0
        while i < tokens.count {
            switch tokens[i] {
            case ">=":
                i += 1
                guard i < tokens.count, let n = Double(tokens[i]) else {
                    throw HCSError(message: "expected number after '>='", line: line)
                }
                min = n
            case "<=":
                i += 1
                guard i < tokens.count, let n = Double(tokens[i]) else {
                    throw HCSError(message: "expected number after '<='", line: line)
                }
                max = n
            default:
                throw HCSError(message: "unexpected token '\(tokens[i])' in constraint", line: line)
            }
            i += 1
        }
        return (contractType, min, max)
    }

    private func interpretRule(
        _ node: Outline,
        condition: ContextGuard?,
        file: String?,
        into rules: inout [Rule],
        order: inout Int
    ) throws {
        let content = String(node.line.trimmed)
        guard let split = splitFirstColon(content), split.right.isEmpty else {
            throw HCSError(message: "expected a selector header ending with ':'", line: node.line.number)
        }
        let selector = try parseSelector(String(split.left), line: node.line.number)

        var properties: [String: TypedValue] = [:]
        for child in node.children {
            let property = try parseProperty(child)
            properties[property.key] = property.value
        }

        rules.append(Rule(
            selector: selector, properties: properties, condition: condition,
            order: order, line: node.line.number, file: file
        ))
        order += 1
    }

    private func parseProperty(_ node: Outline) throws -> (key: String, value: TypedValue) {
        guard node.children.isEmpty else {
            throw HCSError(message: "unexpected nested block under a property", line: node.line.number)
        }
        let content = String(node.line.trimmed)
        guard let split = splitFirstColon(content), !split.right.isEmpty else {
            throw HCSError(message: "expected 'key: value'", line: node.line.number)
        }
        let key = String(split.left)
        guard !key.isEmpty else {
            throw HCSError(message: "empty property key", line: node.line.number)
        }
        return (key, inferType(unquote(split.right)))
    }

    private func inferType(_ s: String) -> TypedValue {
        if s == "true" { return TypedValue(kind: .bool(true), lexeme: s) }
        if s == "false" { return TypedValue(kind: .bool(false), lexeme: s) }
        if let i = Int(s) { return TypedValue(kind: .int(i), lexeme: s) }
        if let d = Double(s), !s.contains(where: { $0.isLetter }) {
            return TypedValue(kind: .double(d), lexeme: s)
        }
        return TypedValue(kind: .string(s), lexeme: s)
    }

    // MARK: - Public selector parsing (used by `hypercode explain`)

    /// Parse a CSS-like selector string from user input (e.g. `service > database`).
    public func parseSelector(fromString text: String) throws -> Selector {
        try parseSelector(text, line: 1)
    }

    // MARK: - Selectors & guards

    private func parseGuard(_ text: String, line: Int) throws -> ContextGuard {
        guard text.hasPrefix("@"), let open = text.firstIndex(of: "["), text.hasSuffix("]") else {
            throw HCSError(message: "expected @dimension[value]", line: line)
        }
        let dimension = trim(text[text.index(after: text.startIndex)..<open])
        let value = trim(text[text.index(after: open)..<text.index(before: text.endIndex)])
        guard !dimension.isEmpty, !value.isEmpty else {
            throw HCSError(message: "empty dimension or value in @dimension[value]", line: line)
        }
        return ContextGuard(dimension: String(dimension), value: String(value))
    }

    private func parseSelector(_ text: String, line: Int) throws -> Selector {
        let segments = text.split(separator: ">")
        guard !segments.isEmpty else {
            throw HCSError(message: "empty selector", line: line)
        }
        var result: Selector?
        for segment in segments {
            let simple = try parseSimpleSelector(trim(segment), line: line)
            result = result.map { .child($0, simple) } ?? simple
        }
        return result!
    }

    private func parseSimpleSelector(_ raw: Substring, line: Int) throws -> Selector {
        var text = raw
        if text.count >= 2, let first = text.first, let last = text.last,
           (first == "'" && last == "'") || (first == "\"" && last == "\"") {
            text = text.dropFirst().dropLast()
        }
        guard let marker = text.first else {
            throw HCSError(message: "empty selector segment", line: line)
        }

        let name: Substring
        let build: (String) -> Selector
        switch marker {
        case ".": name = text.dropFirst(); build = Selector.klass
        case "#": name = text.dropFirst(); build = Selector.id
        default:  name = text;             build = Selector.type
        }

        let identifier = String(name)
        guard IdentifierSpec().isSatisfiedBy(identifier) else {
            throw HCSError(message: "invalid selector identifier '\(identifier)'", line: line)
        }
        return build(identifier)
    }

    // MARK: - Small string helpers (Foundation-free)

    private func splitFirstColon(_ content: String) -> (left: Substring, right: Substring)? {
        guard let colon = content.firstIndex(of: ":") else { return nil }
        let left = trim(content[..<colon])
        let right = trim(content[content.index(after: colon)...])
        return (left, right)
    }

    private func unquote(_ s: Substring) -> String {
        if s.count >= 2, let first = s.first, let last = s.last,
           (first == "\"" && last == "\"") || (first == "'" && last == "'") {
            return String(s.dropFirst().dropLast())
        }
        return String(s)
    }

    private func trim(_ s: Substring) -> Substring {
        var result = s
        while let first = result.first, first == " " || first == "\t" { result = result.dropFirst() }
        while let last = result.last, last == " " || last == "\t" { result = result.dropLast() }
        return result
    }
}
