import SpecificationCore

/// Severity of a validation ``Diagnostic``.
public enum Severity: String, Sendable {
    case error
    case warning
}

/// A single validation finding.
public struct Diagnostic: Equatable, Sendable {
    public let severity: Severity
    public let message: String
    public let line: Int?

    public init(severity: Severity, message: String, line: Int? = nil) {
        self.severity = severity
        self.message = message
        self.line = line
    }
}

/// Semantic validation of a `.hc` document and (optionally) a `.hcs` sheet
/// against it. Syntactic validity is already guaranteed by the parser/reader;
/// these checks catch document-level mistakes.
public struct Validator {
    public init() {}

    /// `.hc` checks: every `#id` must be unique across the document.
    public func validate(_ forest: [Command]) -> [Diagnostic] {
        var diagnostics: [Diagnostic] = []
        var firstLineForId: [String: Int] = [:]

        func walk(_ nodes: [Command]) {
            for node in nodes {
                if let id = node.id {
                    if let firstLine = firstLineForId[id] {
                        diagnostics.append(
                            Diagnostic(
                                severity: .error,
                                message: "duplicate id '#\(id)' (first defined at line \(firstLine))",
                                line: node.line
                            )
                        )
                    } else {
                        firstLineForId[id] = node.line
                    }
                }
                walk(node.children)
            }
        }
        walk(forest)
        return diagnostics
    }

    /// `.hcs` checks: flag rules whose selector matches no node in the forest
    /// (likely a typo or a dead rule).
    public func validate(_ sheet: CascadeSheet, against forest: [Command]) -> [Diagnostic] {
        sheet.rules.compactMap { rule in
            anyNode(forest, ancestors: [], matches: selectorSpec(rule.selector))
                ? nil
                : Diagnostic(severity: .warning, message: "selector '\(rule.selector)' matches no node", line: rule.line)
        }
    }

    private func anyNode(
        _ nodes: [Command],
        ancestors: [Command],
        matches spec: AnySpecification<NodeContext>
    ) -> Bool {
        for node in nodes {
            if spec.isSatisfiedBy(NodeContext(node: node, ancestors: ancestors)) { return true }
            if anyNode(node.children, ancestors: ancestors + [node], matches: spec) { return true }
        }
        return false
    }
}
