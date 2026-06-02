/// A cascade-sheet selector addressing nodes in a `.hc` tree (RFC §4.2.1).
public indirect enum Selector: Equatable, Sendable {
    /// Type selector — matches a command by name: `Database`.
    case type(String)
    /// Class selector — matches any command carrying the class: `.pooled`.
    case klass(String)
    /// Id selector — matches the command with the id: `#primary-db`.
    case id(String)
    /// Child selector — `ancestor > descendant`, the descendant a direct child.
    case child(Selector, Selector)
}

/// CSS-like specificity `(ids, classes, types)`, compared lexicographically
/// (RFC §4.2.3): id beats class beats type.
public struct Specificity: Comparable, Equatable, Sendable {
    public let ids: Int
    public let classes: Int
    public let types: Int

    public init(ids: Int, classes: Int, types: Int) {
        self.ids = ids
        self.classes = classes
        self.types = types
    }

    public static func < (lhs: Specificity, rhs: Specificity) -> Bool {
        (lhs.ids, lhs.classes, lhs.types) < (rhs.ids, rhs.classes, rhs.types)
    }
}

public extension Selector {
    /// The selector's specificity, summing components across child chains.
    var specificity: Specificity {
        switch self {
        case .type:
            return Specificity(ids: 0, classes: 0, types: 1)
        case .klass:
            return Specificity(ids: 0, classes: 1, types: 0)
        case .id:
            return Specificity(ids: 1, classes: 0, types: 0)
        case let .child(ancestor, descendant):
            let a = ancestor.specificity
            let d = descendant.specificity
            return Specificity(ids: a.ids + d.ids, classes: a.classes + d.classes, types: a.types + d.types)
        }
    }
}

extension Selector: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .type(name): return name
        case let .klass(name): return ".\(name)"
        case let .id(name): return "#\(name)"
        case let .child(ancestor, descendant): return "\(ancestor) > \(descendant)"
        }
    }
}
