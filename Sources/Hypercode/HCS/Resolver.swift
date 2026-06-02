import SpecificationCore

/// The active execution context, e.g. `["env": "production"]` or `["client": "A"]`,
/// against which `@dimension[value]` guards are evaluated.
public typealias ResolutionContext = [String: String]

/// Where a resolved value came from: the winning selector and its source line.
public struct Provenance: Equatable, Sendable {
    public let selector: Selector
    public let line: Int

    public init(selector: Selector, line: Int) {
        self.selector = selector
        self.line = line
    }
}

/// A resolved property value with its provenance.
public struct ResolvedValue: Equatable, Sendable {
    public let value: String
    public let provenance: Provenance

    public init(value: String, provenance: Provenance) {
        self.value = value
        self.provenance = provenance
    }
}

/// A `.hc` node with its cascade-resolved properties and resolved children.
public struct ResolvedNode: Equatable, Sendable {
    public let type: String
    public let className: String?
    public let id: String?
    public let properties: [String: ResolvedValue]
    public let children: [ResolvedNode]

    public init(
        type: String,
        className: String? = nil,
        id: String? = nil,
        properties: [String: ResolvedValue] = [:],
        children: [ResolvedNode] = []
    ) {
        self.type = type
        self.className = className
        self.id = id
        self.properties = properties
        self.children = children
    }
}

extension Rule {
    /// Whether this rule's guard is active in the given context.
    func isActive(in context: ResolutionContext) -> Bool {
        guard let condition else { return true }
        return context[condition.dimension] == condition.value
    }
}

/// A single rule's contribution of a value to one property key.
private struct Contribution {
    let value: String
    let precedence: Precedence
    let provenance: Provenance
}

/// The cascade precedence key: specificity first, then source order.
private struct Precedence: Comparable {
    let specificity: Specificity
    let order: Int

    static func < (lhs: Precedence, rhs: Precedence) -> Bool {
        if lhs.specificity != rhs.specificity { return lhs.specificity < rhs.specificity }
        return lhs.order < rhs.order
    }
}

/// Decides the winning value for a property from its competing contributions —
/// the cascade, expressed as a `DecisionSpec`.
private struct PropertyCascade: DecisionSpec {
    typealias Context = [Contribution]
    typealias Result = ResolvedValue

    func decide(_ candidates: [Contribution]) -> ResolvedValue? {
        guard let winner = candidates.max(by: { $0.precedence < $1.precedence }) else {
            return nil
        }
        return ResolvedValue(value: winner.value, provenance: winner.provenance)
    }
}

/// Applies a cascade sheet to a `.hc` tree under a given context, producing a
/// resolved graph (RFC §4.2): selectors match nodes, properties cascade by
/// specificity and source order, each resolved value carrying its provenance.
public struct Resolver {
    private let sheet: CascadeSheet
    private let context: ResolutionContext

    public init(sheet: CascadeSheet, context: ResolutionContext = [:]) {
        self.sheet = sheet
        self.context = context
    }

    public func resolve(_ forest: [Command]) -> [ResolvedNode] {
        forest.map { resolve($0, ancestors: []) }
    }

    private func resolve(_ node: Command, ancestors: [Command]) -> ResolvedNode {
        let nodeContext = NodeContext(node: node, ancestors: ancestors)

        var contributions: [String: [Contribution]] = [:]
        for rule in sheet.rules where rule.isActive(in: context) {
            guard selectorSpec(rule.selector).isSatisfiedBy(nodeContext) else { continue }
            let precedence = Precedence(specificity: rule.specificity, order: rule.order)
            let provenance = Provenance(selector: rule.selector, line: rule.line)
            for (key, value) in rule.properties {
                contributions[key, default: []].append(
                    Contribution(value: value, precedence: precedence, provenance: provenance)
                )
            }
        }

        let cascade = PropertyCascade()
        var properties: [String: ResolvedValue] = [:]
        for (key, candidates) in contributions {
            properties[key] = cascade.decide(candidates)
        }

        let children = node.children.map { resolve($0, ancestors: ancestors + [node]) }
        return ResolvedNode(
            type: node.type,
            className: node.className,
            id: node.id,
            properties: properties,
            children: children
        )
    }
}
