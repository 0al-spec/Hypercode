import SpecificationCore

/// The active execution context, e.g. `["env": "production"]` or `["client": "A"]`,
/// against which `@dimension[value]` guards are evaluated.
public typealias ResolutionContext = [String: String]

/// Where a resolved value came from: the winning selector, file, and source line.
public struct Provenance: Equatable, Sendable {
    public let selector: Selector
    public let file: String?
    public let line: Int

    public init(selector: Selector, file: String? = nil, line: Int) {
        self.selector = selector
        self.file = file
        self.line = line
    }
}

/// A resolved property value with its cascade winner, all losing matches, and provenance.
public struct ResolvedValue: Equatable, Sendable {
    public let value: TypedValue
    public let provenance: Provenance
    public let winner: Match
    /// Losing candidates sorted descending by (specificity, source order).
    public let losers: [Match]

    public init(value: TypedValue, provenance: Provenance, winner: Match, losers: [Match]) {
        self.value = value
        self.provenance = provenance
        self.winner = winner
        self.losers = losers
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
    let value: TypedValue
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
/// the cascade, expressed as a `DecisionSpec`. Retains all losing candidates for
/// the explain command and IR v2.
private struct PropertyCascade: DecisionSpec {
    typealias Context = [Contribution]
    typealias Result = ResolvedValue

    func decide(_ candidates: [Contribution]) -> ResolvedValue? {
        guard !candidates.isEmpty else { return nil }
        let sorted = candidates.sorted { $0.precedence > $1.precedence }
        let w = sorted[0]
        let winner = Match(
            value: w.value,
            selector: w.provenance.selector,
            file: w.provenance.file,
            line: w.provenance.line,
            specificity: w.precedence.specificity,
            order: w.precedence.order
        )
        let losers = sorted.dropFirst().map { c in
            Match(
                value: c.value,
                selector: c.provenance.selector,
                file: c.provenance.file,
                line: c.provenance.line,
                specificity: c.precedence.specificity,
                order: c.precedence.order
            )
        }
        return ResolvedValue(
            value: w.value,
            provenance: w.provenance,
            winner: winner,
            losers: losers
        )
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
            let provenance = Provenance(selector: rule.selector, file: rule.file, line: rule.line)
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
