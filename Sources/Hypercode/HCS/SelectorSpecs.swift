import SpecificationCore

/// A `.hc` node together with its ancestor path (root → parent), the candidate
/// a selector specification is evaluated against.
public struct NodeContext: Sendable {
    public let node: Command
    public let ancestors: [Command]

    public init(node: Command, ancestors: [Command]) {
        self.node = node
        self.ancestors = ancestors
    }

    public var parent: Command? { ancestors.last }
}

/// Matches a node by its command name.
public struct TypeSelectorSpec: Specification {
    public let name: String
    public init(_ name: String) { self.name = name }
    public func isSatisfiedBy(_ candidate: NodeContext) -> Bool {
        candidate.node.type == name
    }
}

/// Matches a node carrying the given class.
public struct ClassSelectorSpec: Specification {
    public let name: String
    public init(_ name: String) { self.name = name }
    public func isSatisfiedBy(_ candidate: NodeContext) -> Bool {
        candidate.node.className == name
    }
}

/// Matches the node with the given id.
public struct IdSelectorSpec: Specification {
    public let name: String
    public init(_ name: String) { self.name = name }
    public func isSatisfiedBy(_ candidate: NodeContext) -> Bool {
        candidate.node.id == name
    }
}

/// Matches when the descendant selector matches the node and the ancestor
/// selector matches its immediate parent (a direct-child relationship).
public struct ChildSelectorSpec: Specification {
    public let ancestor: AnySpecification<NodeContext>
    public let descendant: AnySpecification<NodeContext>

    public init(ancestor: AnySpecification<NodeContext>, descendant: AnySpecification<NodeContext>) {
        self.ancestor = ancestor
        self.descendant = descendant
    }

    public func isSatisfiedBy(_ candidate: NodeContext) -> Bool {
        guard descendant.isSatisfiedBy(candidate), let parent = candidate.parent else {
            return false
        }
        let parentContext = NodeContext(node: parent, ancestors: Array(candidate.ancestors.dropLast()))
        return ancestor.isSatisfiedBy(parentContext)
    }
}

/// Builds the matching specification for a selector, composing child selectors
/// out of the simple ones.
public func selectorSpec(_ selector: Selector) -> AnySpecification<NodeContext> {
    switch selector {
    case let .type(name):
        return AnySpecification(TypeSelectorSpec(name))
    case let .klass(name):
        return AnySpecification(ClassSelectorSpec(name))
    case let .id(name):
        return AnySpecification(IdSelectorSpec(name))
    case let .child(ancestor, descendant):
        return AnySpecification(
            ChildSelectorSpec(ancestor: selectorSpec(ancestor), descendant: selectorSpec(descendant))
        )
    }
}
