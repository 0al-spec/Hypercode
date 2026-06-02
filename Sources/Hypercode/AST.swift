/// A node in a parsed Hypercode (`.hc`) document: a command with an optional
/// class and id, plus an indented block of child commands.
///
/// Grammar: `command ::= identifier [ "." identifier ] [ "#" identifier ]`
public struct Command: Sendable {
    /// The command identifier (the entity / command name).
    public let type: String
    /// Optional `.class` marker, used by HCS selectors. `nil` if absent.
    public let className: String?
    /// Optional `#id` marker, used by HCS selectors. `nil` if absent.
    public let id: String?
    /// Direct children declared in the indented block beneath this command.
    public let children: [Command]
    /// 1-based source line of the command (excluded from equality).
    public let line: Int

    public init(
        type: String,
        className: String? = nil,
        id: String? = nil,
        children: [Command] = [],
        line: Int = 0
    ) {
        self.type = type
        self.className = className
        self.id = id
        self.children = children
        self.line = line
    }
}

extension Command: Equatable {
    /// Structural equality. Source position (`line`) is intentionally excluded so
    /// that expected ASTs in tests need not track line numbers.
    public static func == (lhs: Command, rhs: Command) -> Bool {
        lhs.type == rhs.type
            && lhs.className == rhs.className
            && lhs.id == rhs.id
            && lhs.children == rhs.children
    }
}

extension Command: CustomStringConvertible {
    public var description: String { Command.tree([self]) }

    /// Renders a forest of commands as an indented tree, e.g.
    /// ```
    /// Application
    ///   Button (class: primary, id: ok)
    /// ```
    public static func tree(_ forest: [Command], indent: Int = 0) -> String {
        var out = ""
        for node in forest {
            out += String(repeating: "  ", count: indent)
            out += node.type
            var attributes: [String] = []
            if let className = node.className { attributes.append("class: \(className)") }
            if let id = node.id { attributes.append("id: \(id)") }
            if !attributes.isEmpty {
                out += " (" + attributes.joined(separator: ", ") + ")"
            }
            out += "\n"
            out += tree(node.children, indent: indent + 1)
        }
        return out
    }
}
