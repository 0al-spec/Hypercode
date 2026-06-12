/// The cascade trace for one resolved property on one matched node.
public struct PropertyTrace: Sendable {
    public let key: String
    public let winner: Match
    public let losers: [Match]
}

/// All cascade traces for one node matched by the explain query.
public struct NodeTrace: Sendable {
    /// Human-readable selector path from the root, e.g. "Service > Database".
    public let nodePath: String
    /// One trace per property (filtered to the queried property if provided).
    public let properties: [PropertyTrace]
}

/// Walks a resolved tree to produce cascade traces for every node that matches
/// a given selector. Used by `hypercode explain`.
public struct Explainer {
    private let commands: [Command]
    private let resolved: [ResolvedNode]

    public init(commands: [Command], resolved: [ResolvedNode]) {
        self.commands = commands
        self.resolved = resolved
    }

    /// Returns cascade traces for every node matching `selector`.
    /// - Parameters:
    ///   - selector: The selector to match against the tree.
    ///   - property: If non-nil, only include this property key in each trace.
    public func explain(selector: Selector, property: String?) -> [NodeTrace] {
        var results: [NodeTrace] = []
        walk(
            commands: commands, resolved: resolved,
            ancestors: [], pathComponents: [],
            selector: selector, property: property,
            into: &results
        )
        return results
    }

    // MARK: - Private tree walk

    private func walk(
        commands: [Command],
        resolved: [ResolvedNode],
        ancestors: [Command],
        pathComponents: [String],
        selector: Selector,
        property: String?,
        into results: inout [NodeTrace]
    ) {
        // The resolver preserves tree shape, so the two arrays are parallel by
        // construction — fail fast in debug builds if a caller breaks that.
        assert(commands.count == resolved.count,
               "command/resolved tree shape mismatch (\(commands.count) vs \(resolved.count))")
        for (cmd, node) in zip(commands, resolved) {
            let context = NodeContext(node: cmd, ancestors: ancestors)
            let nodeLabel = nodeLabel(cmd)
            let path = (pathComponents + [nodeLabel]).joined(separator: " > ")

            if selectorSpec(selector).isSatisfiedBy(context) {
                let traces = propertyTraces(node: node, filter: property)
                results.append(NodeTrace(nodePath: path, properties: traces))
            }

            walk(
                commands: cmd.children, resolved: node.children,
                ancestors: ancestors + [cmd], pathComponents: pathComponents + [nodeLabel],
                selector: selector, property: property,
                into: &results
            )
        }
    }

    private func propertyTraces(node: ResolvedNode, filter: String?) -> [PropertyTrace] {
        let keys = node.properties.keys.sorted()
        return keys.compactMap { key in
            guard filter == nil || key == filter else { return nil }
            let rv = node.properties[key]!
            return PropertyTrace(key: key, winner: rv.winner, losers: rv.losers)
        }
    }

    private func nodeLabel(_ cmd: Command) -> String {
        var label = cmd.type
        if let c = cmd.className { label += ".\(c)" }
        if let i = cmd.id { label += "#\(i)" }
        return label
    }
}

// MARK: - Text rendering

extension NodeTrace {
    public func renderText() -> String {
        var out = ""
        for trace in properties {
            out += "  \(trace.key)\n"
            out += renderMatch(trace.winner, role: "WINNER")
            if !trace.losers.isEmpty {
                out += "    \(String(repeating: "─", count: 20))\n"
                for loser in trace.losers {
                    out += renderMatch(loser, role: "losing")
                }
            }
        }
        return out
    }

    private func renderMatch(_ m: Match, role: String) -> String {
        // "    WINNER   selector { value: X }"
        // "             file: f  line: N  specificity: (i,c,t)  order: N"
        let prefix = "    " + role.padding(toLength: 7, withPad: " ", startingAt: 0) + "  "
        let cont   = String(repeating: " ", count: prefix.count)
        let spec   = "(\(m.specificity.ids),\(m.specificity.classes),\(m.specificity.types))"
        var line1 = prefix + "\(m.selector) { value: \(m.value.rawString) }\n"
        var line2 = cont
        if let f = m.file { line2 += "file: \(f)  " }
        line2 += "line: \(m.line)  specificity: \(spec)  order: \(m.order)\n"
        return line1 + line2
    }
}
