import SpecificationCore

/// Validates resolved property values against the contracts that govern each
/// node (Resolution §7.3, diagnostic HC2104). Contracts accumulate by
/// intersection, so a value must satisfy **every** applicable contract
/// individually: type conformance, declared bounds, and required presence.
///
/// Resolution is context-dependent, so unlike the static `ContractValidator`
/// this check runs on the resolved graph — the same `.hcs` can be clean under
/// one `--ctx` and violating under another.
public struct ContractValueValidator {
    public init() {}

    public func validate(
        resolved: [ResolvedNode],
        commands: [Command],
        contracts: [SelectorContract]
    ) -> [Diagnostic] {
        guard !contracts.isEmpty else { return [] }
        var diagnostics: [Diagnostic] = []
        walk(commands: commands, resolved: resolved, ancestors: [],
             contracts: contracts, into: &diagnostics)
        return diagnostics
    }

    // MARK: - Tree walk

    private func walk(
        commands: [Command],
        resolved: [ResolvedNode],
        ancestors: [Command],
        contracts: [SelectorContract],
        into diagnostics: inout [Diagnostic]
    ) {
        // The resolver preserves tree shape, so the two arrays are parallel by
        // construction — fail fast in debug builds rather than silently skip
        // validation of trailing nodes.
        assert(commands.count == resolved.count,
               "command/resolved tree shape mismatch (\(commands.count) vs \(resolved.count))")
        for (cmd, node) in zip(commands, resolved) {
            let context = NodeContext(node: cmd, ancestors: ancestors)
            let applicable = contracts.filter { selectorSpec($0.selector).isSatisfiedBy(context) }
            for contract in applicable {
                checkNode(cmd, node, against: contract, into: &diagnostics)
            }
            walk(commands: cmd.children, resolved: node.children,
                 ancestors: ancestors + [cmd], contracts: contracts, into: &diagnostics)
        }
    }

    private func checkNode(
        _ cmd: Command,
        _ node: ResolvedNode,
        against contract: SelectorContract,
        into diagnostics: inout [Diagnostic]
    ) {
        for key in contract.properties.keys.sorted() {
            let constraint = contract.properties[key]!
            guard let resolvedValue = node.properties[key] else {
                if constraint.required {
                    diagnostics.append(Diagnostic(
                        severity: .error, code: "HC2104",
                        message: "node '\(label(cmd))' is missing required property '\(key)' — required by contract '\(contract.selector)'",
                        file: contract.file,
                        range: SourceRange(SourcePosition(line: contract.line, column: 1))
                    ))
                }
                continue
            }
            diagnostics += check(
                resolvedValue, key: key,
                constraint: constraint, selector: contract.selector
            )
        }
    }

    // MARK: - Value checks

    private func check(
        _ rv: ResolvedValue,
        key: String,
        constraint: PropertyContract,
        selector: Selector
    ) -> [Diagnostic] {
        // Violations point at the winning rule — where the value was written —
        // not at the contract declaration.
        let winner = rv.winner
        let range = SourceRange(SourcePosition(line: winner.line, column: 1))

        // Type conformance. An int satisfies a float contract (ℤ ⊂ ℝ);
        // everything else must match exactly.
        let numeric: NumericValue?
        switch (rv.value.kind, constraint.type) {
        case (.int(let i), .int), (.int(let i), .float):
            numeric = .int(i)
        case (.double(let d), .float):
            numeric = .double(d)
        case (.string, .string), (.bool, .bool):
            numeric = nil
        default:
            return [Diagnostic(
                severity: .error, code: "HC2104",
                message: "contract violation for '\(key)': value '\(rv.value.rawString)' (\(kindName(rv.value.kind))) does not satisfy type '\(constraint.type.rawValue)' from contract '\(selector)'",
                file: winner.file, range: range
            )]
        }

        var diags: [Diagnostic] = []
        if let n = numeric {
            if let min = constraint.min, n.isBelow(min) {
                diags.append(Diagnostic(
                    severity: .error, code: "HC2104",
                    message: "contract violation for '\(key)': \(rv.value.rawString) is below lower bound \(min) from contract '\(selector)'",
                    file: winner.file, range: range
                ))
            }
            if let max = constraint.max, n.isAbove(max) {
                diags.append(Diagnostic(
                    severity: .error, code: "HC2104",
                    message: "contract violation for '\(key)': \(rv.value.rawString) exceeds upper bound \(max) from contract '\(selector)'",
                    file: winner.file, range: range
                ))
            }
        }
        return diags
    }

    // MARK: - Helpers

    /// A resolved numeric value compared against `Double` bounds without
    /// losing integer precision: `Double(i)` rounds beyond 2^53, which could
    /// hide a violation like `9007199254740993` under `int <= 9007199254740992`.
    /// Integer values compare in the `Int` domain whenever the bound is an
    /// exactly representable integer.
    private enum NumericValue {
        case int(Int)
        case double(Double)

        func isBelow(_ bound: Double) -> Bool {
            switch self {
            case .double(let d): return d < bound
            case .int(let i):
                if let exact = Int(exactly: bound) { return i < exact }
                return Double(i) < bound
            }
        }

        func isAbove(_ bound: Double) -> Bool {
            switch self {
            case .double(let d): return d > bound
            case .int(let i):
                if let exact = Int(exactly: bound) { return i > exact }
                return Double(i) > bound
            }
        }
    }

    private func kindName(_ kind: TypedValue.Kind) -> String {
        switch kind {
        case .string: return "string"
        case .int: return "int"
        case .double: return "float"
        case .bool: return "bool"
        }
    }

    private func label(_ cmd: Command) -> String {
        var text = cmd.type
        if let c = cmd.className { text += ".\(c)" }
        if let i = cmd.id { text += "#\(i)" }
        return text
    }
}
