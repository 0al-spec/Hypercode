/// A context guard from an `@dimension[value]` block, e.g. `@env[production]`.
public struct ContextGuard: Equatable, Sendable {
    public let dimension: String
    public let value: String

    public init(dimension: String, value: String) {
        self.dimension = dimension
        self.value = value
    }
}

/// A single cascade rule: a selector, the properties it sets, an optional
/// context guard, and its source order. Specificity is derived from the selector.
public struct Rule: Equatable, Sendable {
    public let selector: Selector
    public let properties: [String: String]
    /// `nil` for a global rule; otherwise the `@dimension[value]` it lives under.
    public let condition: ContextGuard?
    /// 0-based position in the sheet, used to break specificity ties.
    public let order: Int
    /// 1-based source line of the selector header (for provenance).
    public let line: Int

    public init(
        selector: Selector,
        properties: [String: String],
        condition: ContextGuard?,
        order: Int,
        line: Int
    ) {
        self.selector = selector
        self.properties = properties
        self.condition = condition
        self.order = order
        self.line = line
    }

    public var specificity: Specificity { selector.specificity }
}

/// A parsed `.hcs` cascade sheet: an ordered list of rules.
public struct CascadeSheet: Equatable, Sendable {
    public let rules: [Rule]

    public init(rules: [Rule]) {
        self.rules = rules
    }
}
