/// A source position: 1-based line and column (the human / editor convention).
public struct SourcePosition: Equatable, Sendable {
    public let line: Int
    public let column: Int

    public init(line: Int, column: Int) {
        self.line = line
        self.column = column
    }
}

/// A source range. For a point diagnostic, `start == end`.
public struct SourceRange: Equatable, Sendable {
    public let start: SourcePosition
    public let end: SourcePosition

    public init(start: SourcePosition, end: SourcePosition) {
        self.start = start
        self.end = end
    }

    public init(_ position: SourcePosition) {
        self.start = position
        self.end = position
    }
}

/// Diagnostic severity. Raw values match LSP `DiagnosticSeverity`.
public enum Severity: Int, Sendable {
    case error = 1
    case warning = 2
    case information = 3
    case hint = 4
}

/// A structured, machine-readable diagnostic — the unit consumed by tools and,
/// via the LSP server, by editors.
public struct Diagnostic: Equatable, Sendable {
    public let severity: Severity
    /// A stable diagnostic code, e.g. `HC1101`.
    public let code: String
    public let message: String
    /// Source file path, when known.
    public let file: String?
    /// 1-based source range. `nil` when the diagnostic is not positional.
    public let range: SourceRange?

    public init(
        severity: Severity,
        code: String,
        message: String,
        file: String? = nil,
        range: SourceRange? = nil
    ) {
        self.severity = severity
        self.code = code
        self.message = message
        self.file = file
        self.range = range
    }
}

/// An error that can be presented as a ``Diagnostic``.
public protocol DiagnosticConvertible: Error {
    func diagnostic(file: String?) -> Diagnostic
}

extension LexError: DiagnosticConvertible {
    public func diagnostic(file: String?) -> Diagnostic {
        Diagnostic(
            severity: .error, code: "HC1001", message: message, file: file,
            range: SourceRange(SourcePosition(line: line, column: column))
        )
    }
}

extension ParseError: DiagnosticConvertible {
    public func diagnostic(file: String?) -> Diagnostic {
        Diagnostic(
            severity: .error, code: "HC1101", message: message, file: file,
            range: SourceRange(SourcePosition(line: line, column: column))
        )
    }
}

extension HCSError: DiagnosticConvertible {
    public func diagnostic(file: String?) -> Diagnostic {
        Diagnostic(
            severity: .error, code: "HC2001", message: message, file: file,
            range: SourceRange(SourcePosition(line: line, column: 1))
        )
    }
}
