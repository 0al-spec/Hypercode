import SpecificationCore

/// Validates monotonicity invariants across `@contract:` blocks in a `.hcs` sheet.
///
/// Rule (RFC §9.4 / HC-111): A more specific selector MAY narrow constraints
/// (tighter interval, required instead of optional), but MUST NOT weaken them
/// (wider interval, demote required to optional, change type).
///
/// Like the CSS cascade, specificity only relates rules that can govern the
/// same node — a pair of contracts is checked only when at least one node in
/// the document is matched by both selectors (review R3). An omitted bound is
/// not a violation: the effective contract for a node is the intersection of
/// all applicable contracts, so absent bounds inherit (decision R12).
///
/// Diagnostic codes:
///   HC2101 — type mismatch (between specificities, or at equal specificity
///            where the intersection would be unsatisfiable)
///   HC2102 — interval widening (more specific selector widens lower or upper bound)
///   HC2103 — optional weakening (more specific selector makes a required property optional)
public struct ContractValidator {
    public init() {}

    public func validate(
        _ contracts: [SelectorContract],
        against forest: [Command]
    ) -> [Diagnostic] {
        var diagnostics: [Diagnostic] = []
        for i in 0..<contracts.count {
            for j in (i + 1)..<contracts.count {
                let first = contracts[i]
                let second = contracts[j]
                guard overlaps(first.selector, second.selector, in: forest) else { continue }

                if first.selector.specificity == second.selector.specificity {
                    diagnostics += checkEqualSpecificity(first, second)
                } else {
                    let (less, more) = first.selector.specificity < second.selector.specificity
                        ? (first, second)
                        : (second, first)
                    diagnostics += checkNarrowing(less: less, more: more)
                }
            }
        }
        return diagnostics
    }

    // MARK: - Pair checks

    private func checkNarrowing(less: SelectorContract, more: SelectorContract) -> [Diagnostic] {
        var diags: [Diagnostic] = []
        for key in less.properties.keys.sorted() {
            guard let lessContract = less.properties[key],
                  let moreContract = more.properties[key] else { continue }
            diags += check(
                key: key, less: lessContract, lessSelector: less.selector,
                more: moreContract, moreSelector: more.selector,
                file: more.file, line: more.line
            )
        }
        return diags
    }

    /// At equal specificity both contracts apply with equal force; their types
    /// must agree or the intersection is unsatisfiable.
    private func checkEqualSpecificity(
        _ first: SelectorContract, _ second: SelectorContract
    ) -> [Diagnostic] {
        var diags: [Diagnostic] = []
        for key in first.properties.keys.sorted() {
            guard let a = first.properties[key], let b = second.properties[key] else { continue }
            if a.type != b.type {
                diags.append(Diagnostic(
                    severity: .error, code: "HC2101",
                    message: "contract for '\(key)': selector '\(second.selector)' declares type '\(b.type.rawValue)' but '\(first.selector)' declares '\(a.type.rawValue)' at equal specificity — the effective contract is unsatisfiable",
                    file: second.file,
                    range: SourceRange(SourcePosition(line: second.line, column: 1))
                ))
            }
        }
        return diags
    }

    private func check(
        key: String,
        less: PropertyContract, lessSelector: Selector,
        more: PropertyContract, moreSelector: Selector,
        file: String?, line: Int
    ) -> [Diagnostic] {
        var diags: [Diagnostic] = []
        let range = SourceRange(SourcePosition(line: line, column: 1))

        if more.type != less.type {
            diags.append(Diagnostic(
                severity: .error, code: "HC2101",
                message: "contract for '\(key)': selector '\(moreSelector)' has type '\(more.type.rawValue)' but inherits type '\(less.type.rawValue)' from '\(lessSelector)' — type must be identical",
                file: file, range: range
            ))
        }

        if let lessMin = less.min, let moreMin = more.min, moreMin < lessMin {
            diags.append(Diagnostic(
                severity: .error, code: "HC2102",
                message: "contract for '\(key)': selector '\(moreSelector)' widens lower bound (\(moreMin) < \(lessMin) from '\(lessSelector)') — contracts must narrow",
                file: file, range: range
            ))
        }

        if let lessMax = less.max, let moreMax = more.max, moreMax > lessMax {
            diags.append(Diagnostic(
                severity: .error, code: "HC2102",
                message: "contract for '\(key)': selector '\(moreSelector)' widens upper bound (\(moreMax) > \(lessMax) from '\(lessSelector)') — contracts must narrow",
                file: file, range: range
            ))
        }

        if less.required && !more.required {
            diags.append(Diagnostic(
                severity: .error, code: "HC2103",
                message: "contract for '\(key)': selector '\(moreSelector)' makes required property optional — selector '\(lessSelector)' requires it",
                file: file, range: range
            ))
        }

        return diags
    }

    // MARK: - Selector overlap

    /// Whether at least one node in the forest is matched by both selectors.
    private func overlaps(_ a: Selector, _ b: Selector, in forest: [Command]) -> Bool {
        let specA = selectorSpec(a)
        let specB = selectorSpec(b)

        func walk(_ nodes: [Command], ancestors: [Command]) -> Bool {
            for node in nodes {
                let context = NodeContext(node: node, ancestors: ancestors)
                if specA.isSatisfiedBy(context) && specB.isSatisfiedBy(context) { return true }
                if walk(node.children, ancestors: ancestors + [node]) { return true }
            }
            return false
        }
        return walk(forest, ancestors: [])
    }
}
