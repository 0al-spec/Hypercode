import SpecificationCore

/// Satisfied by a command head conforming to the grammar
/// `command ::= identifier [ "." identifier ] [ "#" identifier ]`.
///
/// Validates the `Type.class#id` shape — including the class-before-id order —
/// by peeling the optional `#id` then `.class` and requiring each segment, and
/// the remaining type, to be a valid identifier.
public struct CommandSpec: Specification {
    private let identifier = IdentifierSpec()

    public init() {}

    public func isSatisfiedBy(_ candidate: String) -> Bool {
        var rest = Substring(candidate)

        if let hash = rest.firstIndex(of: "#") {
            let idPart = rest[rest.index(after: hash)...]
            guard identifier.isSatisfiedBy(String(idPart)) else { return false }
            rest = rest[..<hash]
        }

        if let dot = rest.firstIndex(of: ".") {
            let classPart = rest[rest.index(after: dot)...]
            guard identifier.isSatisfiedBy(String(classPart)) else { return false }
            rest = rest[..<dot]
        }

        return identifier.isSatisfiedBy(String(rest))
    }
}
