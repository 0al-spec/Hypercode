/// A lexical token produced by ``Lexer`` from Hypercode (`.hc`) source.
public struct Token: Equatable, Sendable {
    /// The kinds of token the Hypercode lexer can emit.
    ///
    /// `indent` and `dedent` are *synthetic*: they are not present in the source
    /// text but are derived from changes in leading whitespace (the off-side rule).
    public enum Kind: Equatable, Sendable {
        case identifier(String)
        case dot          // "."
        case hash         // "#"
        case newline      // end of a command line
        case indent       // indentation level increased
        case dedent       // indentation level decreased
        case eof
    }

    public let kind: Kind
    /// 1-based source line.
    public let line: Int
    /// 1-based source column.
    public let column: Int

    public init(_ kind: Kind, line: Int, column: Int) {
        self.kind = kind
        self.line = line
        self.column = column
    }
}
