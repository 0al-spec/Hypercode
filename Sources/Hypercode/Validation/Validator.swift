import SpecificationCore

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
                                code: "HC3001",
                                message: "duplicate id '#\(id)' (first defined at line \(firstLine))",
                                range: SourceRange(SourcePosition(line: node.line, column: 1))
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
    /// (likely a typo or a dead rule), plus contract monotonicity violations.
    public func validate(_ sheet: CascadeSheet, against forest: [Command]) -> [Diagnostic] {
        let dangling = sheet.rules.compactMap { rule in
            anyNode(forest, ancestors: [], matches: selectorSpec(rule.selector))
                ? nil
                : Diagnostic(severity: .warning, code: "HC3002", message: "selector '\(rule.selector)' matches no node", range: SourceRange(SourcePosition(line: rule.line, column: 1)))
        }
        let contractDiags = ContractValidator().validate(sheet.contracts, against: forest)
        return dangling + contractDiags
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
