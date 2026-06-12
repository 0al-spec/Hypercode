/// An error raised while reading a `.hcs` cascade sheet.
public struct HCSError: Error, Equatable, CustomStringConvertible, Sendable {
    public let message: String
    public let line: Int

    public var description: String { "hcs error at line \(line): \(message)" }
}

/// How `@import` directives are handled while reading a `.hcs` sheet (HC-116).
public enum ImportHandling {
    /// `@import` is an error — the default for single-sheet contexts that
    /// have no way to load other files.
    case unsupported
    /// Directives are validated syntactically but not expanded — live
    /// diagnostics over a lone text buffer (LSP).
    case syntaxOnly
    /// Expand imports. The loader resolves a target *as written* (plus the
    /// importing file, when known) to a canonical file identity and its
    /// source text; the identity is what cycle detection and import-once
    /// dedupe compare, so it must be stable for the same physical sheet.
    case loader((_ target: String, _ importingFile: String?) throws -> (file: String, source: String))
}

/// A minimal, hand-rolled reader for the `.hcs` subset we use today: selector
/// headers, `@dimension[value]` context blocks, `@contract:` blocks,
/// `@import "path"` directives, and `key: value` properties, nested by
/// indentation. No third-party YAML dependency — typed scalars and full YAML
/// come later, only if we ever consume real YAML input.
public struct CascadeSheetReader {
    public init() {}

    /// Parse a `.hcs` source string into a `CascadeSheet`.
    ///
    /// Imports expand depth-first at the position of the directive, so the
    /// importing sheet's own rules come later in source order and win
    /// specificity ties — the importer overrides what it imports. Each sheet
    /// is loaded at most once per `read` (diamonds are fine); a cyclic import
    /// is an error. Rules keep the file they were defined in for provenance.
    ///
    /// - Parameters:
    ///   - file: Optional path of the source file, stored in each `Rule` for provenance.
    ///   - imports: How `@import` directives are handled (default: error).
    public func read(
        _ source: String, file: String? = nil, imports: ImportHandling = .unsupported
    ) throws -> CascadeSheet {
        var state = ReadState()
        if let file {
            state.loaded.insert(file)
            state.stack.append(file)
        }
        try readSheet(source, file: file, imports: imports, state: &state)
        return CascadeSheet(rules: state.rules, contracts: state.contracts)
    }

    /// Accumulator threaded through import expansion: one global rule order
    /// (later = wins ties), the set of files already expanded (import-once),
    /// and the active import chain (cycle detection).
    private struct ReadState {
        var rules: [Rule] = []
        var contracts: [SelectorContract] = []
        var order = 0
        var loaded: Set<String> = []
        var stack: [String] = []
    }

    private func readSheet(
        _ source: String, file: String?, imports: ImportHandling, state: inout ReadState
    ) throws {
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

        var importsAllowed = true
        for node in outline {
            if isImportDirective(node.line.trimmed) {
                try handleImport(node, file: file, imports: imports,
                                 allowed: importsAllowed, state: &state)
            } else {
                importsAllowed = false
                try interpretTopLevel(node, file: file, into: &state.rules,
                                      contracts: &state.contracts, order: &state.order)
            }
        }
    }

    // MARK: - Imports (HC-116)

    /// `@import` only with a word boundary — `@important[x]:` stays a guard.
    private func isImportDirective(_ trimmed: Substring) -> Bool {
        trimmed == "@import" || trimmed.hasPrefix("@import ") || trimmed.hasPrefix("@import\t")
    }

    private func handleImport(
        _ node: Outline, file: String?, imports: ImportHandling,
        allowed: Bool, state: inout ReadState
    ) throws {
        let line = node.line.number
        guard node.children.isEmpty else {
            throw HCSError(message: "unexpected nested block under @import", line: line)
        }
        // CSS discipline: imports first. This is what makes "imported rules
        // come earlier in source order" hold by construction.
        guard allowed else {
            throw HCSError(message: "@import must precede rules, context blocks and contracts", line: line)
        }
        let rest = trim(node.line.trimmed.dropFirst("@import".count))
        guard rest.count >= 2, let first = rest.first, let last = rest.last,
              (first == "\"" && last == "\"") || (first == "'" && last == "'") else {
            throw HCSError(message: "expected @import \"path.hcs\"", line: line)
        }
        let target = String(rest.dropFirst().dropLast())
        guard !target.isEmpty else {
            throw HCSError(message: "empty @import path", line: line)
        }

        switch imports {
        case .unsupported:
            throw HCSError(message: "@import is not supported here (no import loader)", line: line)
        case .syntaxOnly:
            return
        case .loader(let load):
            let loadedFile: String
            let loadedSource: String
            do {
                (loadedFile, loadedSource) = try load(target, file)
            } catch {
                throw HCSError(message: "cannot load @import \"\(target)\": \(error)", line: line)
            }
            if state.stack.contains(loadedFile) {
                let chain = (state.stack + [loadedFile]).joined(separator: " -> ")
                throw HCSError(message: "import cycle: \(chain)", line: line)
            }
            if state.loaded.contains(loadedFile) { return } // diamond: import once
            state.loaded.insert(loadedFile)
            state.stack.append(loadedFile)
            defer { state.stack.removeLast() }
            do {
                try readSheet(loadedSource, file: loadedFile, imports: imports, state: &state)
            } catch let error as HCSError {
                // Point at the @import line, but keep the imported file's
                // own location in the message so the chain stays traceable.
                throw HCSError(message: "\(loadedFile):\(error.line): \(error.message)", line: line)
            }
        }
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
        // Quoting forces string: `zip: "00123"` and `flag: "false"` must stay
        // strings. Type inference runs only on unquoted scalars.
        if isQuoted(split.right) {
            return (key, .string(unquote(split.right)))
        }
        return (key, inferType(String(split.right)))
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

    private func isQuoted(_ s: Substring) -> Bool {
        s.count >= 2 && ((s.first == "\"" && s.last == "\"") || (s.first == "'" && s.last == "'"))
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
