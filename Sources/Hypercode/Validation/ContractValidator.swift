/// Validates monotonicity invariants across `@contract:` blocks in a `.hcs` sheet.
///
/// Rule (RFC §9.4 / HC-111): A more specific selector MAY narrow constraints
/// (tighter interval, required instead of optional), but MUST NOT weaken them
/// (wider interval, demote required to optional, change type).
///
/// Diagnostic codes:
///   HC2101 — type mismatch between selectors of different specificity
///   HC2102 — interval widening (more specific selector widens lower or upper bound)
///   HC2103 — optional weakening (more specific selector makes a required property optional)
public struct ContractValidator {
    public init() {}

    public func validate(_ contracts: [SelectorContract]) -> [Diagnostic] {
        var diagnostics: [Diagnostic] = []
        // Pairwise: for every (less-specific A, more-specific B) pair with A < B,
        // check shared property keys.
        for i in 0..<contracts.count {
            for j in 0..<contracts.count where j != i {
                let a = contracts[i]
                let b = contracts[j]
                guard a.selector.specificity < b.selector.specificity else { continue }
                for (key, aContract) in a.properties {
                    guard let bContract = b.properties[key] else { continue }
                    diagnostics += check(
                        key: key, less: aContract, lessSelector: a.selector,
                        more: bContract, moreSelector: b.selector,
                        file: b.file, line: b.line
                    )
                }
            }
        }
        return diagnostics
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
}
