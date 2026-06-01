import SpecificationCore

/// Classifies a raw `.hc` line into its lexical ``LineKind``, mirroring the
/// `DecisionSpec` pattern used across the 0AL grammar modules: boolean
/// specifications compose into a typed verdict.
public struct LineKindDecision: DecisionSpec {
    public typealias Context = RawLine
    public typealias Result = LineKind

    public init() {}

    public func decide(_ context: RawLine) -> LineKind? {
        if IsBlankLineSpec().isSatisfiedBy(context) {
            return .blank
        }
        return .command
    }
}
