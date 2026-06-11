/// A typed property value inferred at parse time from the raw scalar text.
/// Keeps the source lexeme alongside the typed kind so the v1 emitter
/// round-trips values byte-for-byte (`1.10` stays `1.10`, `0123` stays `0123`).
public struct TypedValue: Equatable, Sendable {
    /// The inferred scalar kind with its canonical value.
    public enum Kind: Equatable, Sendable {
        case string(String)
        case int(Int)
        case double(Double)
        case bool(Bool)
    }

    public let kind: Kind
    /// The source text as written in the sheet (after unquoting).
    public let lexeme: String

    public init(kind: Kind, lexeme: String) {
        self.kind = kind
        self.lexeme = lexeme
    }

    // Factories with canonical lexemes, so call sites read like enum cases.
    public static func string(_ value: String) -> TypedValue {
        TypedValue(kind: .string(value), lexeme: value)
    }
    public static func int(_ value: Int) -> TypedValue {
        TypedValue(kind: .int(value), lexeme: String(value))
    }
    public static func double(_ value: Double) -> TypedValue {
        TypedValue(kind: .double(value), lexeme: String(value))
    }
    public static func bool(_ value: Bool) -> TypedValue {
        TypedValue(kind: .bool(value), lexeme: value ? "true" : "false")
    }

    /// Source-faithful string representation — what the author wrote.
    /// Used by the v1 emitter and `explain` text output.
    public var rawString: String { lexeme }
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

    public init(
        value: TypedValue,
        selector: Selector,
        file: String? = nil,
        line: Int,
        specificity: Specificity,
        order: Int
    ) {
        self.value = value
        self.selector = selector
        self.file = file
        self.line = line
        self.specificity = specificity
        self.order = order
    }
}

// MARK: - Contract types

/// The scalar type a property is constrained to in a `@contract:` block.
public enum ContractType: String, Equatable, Sendable {
    case string, int, float, bool
}

/// A constraint for one property key declared inside a `@contract:` selector block.
public struct PropertyContract: Equatable, Sendable {
    public let type: ContractType
    /// `true` = property must be present; `false` = property may be absent (`key[?]:` syntax).
    public let required: Bool
    /// Lower bound (inclusive). `nil` = no lower bound.
    public let min: Double?
    /// Upper bound (inclusive). `nil` = no upper bound.
    public let max: Double?

    public init(type: ContractType, required: Bool = true, min: Double? = nil, max: Double? = nil) {
        self.type = type
        self.required = required
        self.min = min
        self.max = max
    }
}

/// A `@contract:` block entry: a selector and the property constraints it declares.
public struct SelectorContract: Equatable, Sendable {
    public let selector: Selector
    public let properties: [String: PropertyContract]
    public let file: String?
    public let line: Int

    public init(selector: Selector, properties: [String: PropertyContract],
                file: String? = nil, line: Int) {
        self.selector = selector
        self.properties = properties
        self.file = file
        self.line = line
    }
}

/// A parsed `.hcs` cascade sheet: an ordered list of rules and `@contract:` blocks.
public struct CascadeSheet: Equatable, Sendable {
    public let rules: [Rule]
    public let contracts: [SelectorContract]

    public init(rules: [Rule], contracts: [SelectorContract] = []) {
        self.rules = rules
        self.contracts = contracts
    }
}
