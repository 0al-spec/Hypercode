public extension ResolvedNode {
    /// Renders a resolved forest as an indented tree with each node's resolved
    /// properties and the selector each value came from, e.g.
    /// ```
    /// Logger (class: console)
    ///   - format: json   [.console]
    ///   - level: info   [Logger]
    /// ```
    static func tree(_ forest: [ResolvedNode], indent: Int = 0) -> String {
        var out = ""
        let pad = String(repeating: "  ", count: indent)
        for node in forest {
            out += pad + node.type
            var head: [String] = []
            if let className = node.className { head.append("class: \(className)") }
            if let id = node.id { head.append("id: \(id)") }
            if !head.isEmpty { out += " (" + head.joined(separator: ", ") + ")" }
            out += "\n"
            for key in node.properties.keys.sorted() {
                let resolved = node.properties[key]!
                out += pad + "  - \(key): \(resolved.value)   [\(resolved.provenance.selector)]\n"
            }
            out += tree(node.children, indent: indent + 1)
        }
        return out
    }
}
