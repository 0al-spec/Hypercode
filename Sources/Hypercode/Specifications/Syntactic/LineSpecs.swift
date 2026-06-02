import SpecificationCore

/// Satisfied by blank (empty or whitespace-only) lines.
public struct IsBlankLineSpec: Specification {
    public init() {}

    public func isSatisfiedBy(_ candidate: RawLine) -> Bool {
        candidate.isBlank
    }
}

/// Satisfied by lines that carry content (i.e. not blank).
///
/// Composed as the negation of ``IsBlankLineSpec``, exercising the
/// SpecificationCore combinators.
public struct IsCommandLineSpec: Specification {
    private let spec: AnySpecification<RawLine>

    public init() {
        spec = AnySpecification(IsBlankLineSpec().not())
    }

    public func isSatisfiedBy(_ candidate: RawLine) -> Bool {
        spec.isSatisfiedBy(candidate)
    }
}

/// Satisfied by a non-blank line whose content is a well-formed command head.
public struct ValidCommandLineSpec: Specification {
    private let command = CommandSpec()

    public init() {}

    public func isSatisfiedBy(_ candidate: RawLine) -> Bool {
        !candidate.isBlank && command.isSatisfiedBy(String(candidate.trimmed))
    }
}
