import SpecificationCore

/// Satisfied by strings that form a valid Hypercode identifier:
/// `identifier ::= letter { letter | digit | "_" | "-" }` (ASCII).
///
/// The lexical building block reused by the syntactic command specifications.
public struct IdentifierSpec: Specification {
    public init() {}

    public func isSatisfiedBy(_ candidate: String) -> Bool {
        guard let first = candidate.first, Lexer.isIdentifierStart(first) else {
            return false
        }
        return candidate.dropFirst().allSatisfy(Lexer.isIdentifierPart)
    }
}
