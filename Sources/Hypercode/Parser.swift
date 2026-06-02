/// An error raised while parsing a Hypercode token stream.
public struct ParseError: Error, Equatable, CustomStringConvertible, Sendable {
    public let message: String
    public let line: Int
    public let column: Int

    public var description: String { "parse error at \(line):\(column): \(message)" }
}

/// A recursive-descent parser for Hypercode (`.hc`).
///
/// Grammar:
/// ```
/// hypercode    ::= { command-line }
/// command-line ::= command newline [ block ]
/// command      ::= identifier [ "." identifier ] [ "#" identifier ]
/// block        ::= INDENT { command-line } DEDENT
/// ```
public final class Parser {
    private let tokens: [Token]
    private var position = 0

    public init(tokens: [Token]) {
        self.tokens = tokens
    }

    public convenience init(source: String) throws {
        self.init(tokens: try Lexer(source).tokenize())
    }

    /// Parses the whole document into a forest of top-level commands.
    public func parse() throws -> [Command] {
        var nodes: [Command] = []
        while !check(.eof) {
            if check(.newline) { advance(); continue }
            nodes.append(try parseCommandLine())
        }
        return nodes
    }

    // MARK: - Productions

    // command-line ::= command newline [ block ]
    private func parseCommandLine() throws -> Command {
        let head = try parseCommand()
        try expect(.newline, "expected end of line after command")
        var children: [Command] = []
        if check(.indent) {
            children = try parseBlock()
        }
        return Command(
            type: head.type,
            className: head.className,
            id: head.id,
            children: children,
            line: head.line
        )
    }

    // command ::= identifier [ "." identifier ] [ "#" identifier ]
    private func parseCommand() throws -> (type: String, className: String?, id: String?, line: Int) {
        guard case let .identifier(type) = peek().kind else {
            throw error("expected a command identifier")
        }
        let line = peek().line
        advance()

        var className: String?
        if check(.dot) {
            advance()
            guard case let .identifier(name) = peek().kind else {
                throw error("expected a class name after '.'")
            }
            className = name
            advance()
        }

        var id: String?
        if check(.hash) {
            advance()
            guard case let .identifier(name) = peek().kind else {
                throw error("expected an id name after '#'")
            }
            id = name
            advance()
        }

        return (type, className, id, line)
    }

    // block ::= INDENT { command-line } DEDENT
    private func parseBlock() throws -> [Command] {
        try expect(.indent, "expected an indented block")
        var children: [Command] = []
        while !check(.dedent), !check(.eof) {
            if check(.newline) { advance(); continue }
            children.append(try parseCommandLine())
        }
        try expect(.dedent, "expected end of indented block")
        return children
    }

    // MARK: - Token cursor

    private func peek() -> Token { tokens[position] }

    private func check(_ kind: Token.Kind) -> Bool { peek().kind == kind }

    @discardableResult
    private func advance() -> Token {
        let token = tokens[position]
        if position < tokens.count - 1 { position += 1 }
        return token
    }

    private func expect(_ kind: Token.Kind, _ message: String) throws {
        guard check(kind) else { throw error(message) }
        advance()
    }

    private func error(_ message: String) -> ParseError {
        ParseError(message: message, line: peek().line, column: peek().column)
    }
}
