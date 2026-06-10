/// A typed property value inferred at parse time from the raw scalar text.
public enum TypedValue: Equatable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)

    /// String representation used by the v1 emitter and backward-compatible accessors.
    public var rawString: String {
        switch self {
        case .string(let s): return s
        case .int(let i): return String(i)
        case .double(let d): return String(d)
        case .bool(let b): return b ? "true" : "false"
        }
    }
}

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
    public let properties: [String: TypedValue]
    /// `nil` for a global rule; otherwise the `@dimension[value]` it lives under.
    public let condition: ContextGuard?
    /// 0-based position in the sheet, used to break specificity ties.
    public let order: Int
    /// 1-based source line of the selector header (for provenance).
    public let line: Int
    /// Path of the `.hcs` source file, if known.
    public let file: String?

    public init(
        selector: Selector,
        properties: [String: TypedValue],
        condition: ContextGuard?,
        order: Int,
        line: Int,
        file: String? = nil
    ) {
        self.selector = selector
        self.properties = properties
        self.condition = condition
        self.order = order
        self.line = line
        self.file = file
    }

    public var specificity: Specificity { selector.specificity }
}

/// One rule's contribution to a property in the resolved cascade trace.
public struct Match: Equatable, Sendable {
    public let value: TypedValue
    public let selector: Selector
    public let file: String?
    public let line: Int
    public let specificity: Specificity
    public let order: Int
}

/// A parsed `.hcs` cascade sheet: an ordered list of rules.
public struct CascadeSheet: Equatable, Sendable {
    public let rules: [Rule]

    public init(rules: [Rule]) {
        self.rules = rules
    }
}
