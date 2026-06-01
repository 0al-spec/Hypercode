import SpecificationCore

/// Satisfied by strings that form a valid Hypercode identifier:
/// `identifier ::= letter { letter | digit | "_" | "-" }` (ASCII).
///
/// First adopter of SpecificationCore in the Hypercode core. Grammar and
/// cascade rules are expressed as composable specifications (the 0AL house
/// style); richer lexical / syntactic / semantic specs will follow as the
/// shared grammar-core grows here before Hyperprompt and Ontology adopt it.
public struct IdentifierSpec: Specification {
    public init() {}

    public func isSatisfiedBy(_ candidate: String) -> Bool {
        guard let first = candidate.first, Lexer.isIdentifierStart(first) else {
            return false
        }
        return candidate.dropFirst().allSatisfy(Lexer.isIdentifierPart)
    }
}
