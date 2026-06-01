/// An error raised while tokenizing Hypercode source.
public struct LexError: Error, Equatable, CustomStringConvertible, Sendable {
    public let message: String
    public let line: Int
    public let column: Int

    public var description: String { "lex error at \(line):\(column): \(message)" }
}

/// Tokenizes Hypercode (`.hc`) source into a flat token stream, translating
/// leading whitespace into synthetic `indent` / `dedent` tokens (the off-side
/// rule) via an indentation stack — mirroring the reference ANTLR lexer.
public struct Lexer {
    private let source: String

    public init(_ source: String) {
        self.source = source
    }

    public func tokenize() throws -> [Token] {
        var tokens: [Token] = []
        var indentStack: [Int] = [0]
        var lastLine = 1

        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false)

        for (index, rawLine) in rawLines.enumerated() {
            var line = rawLine
            if line.hasSuffix("\r") { line = line.dropLast() }

            // Blank / whitespace-only lines carry no structure and never change indentation.
            if line.allSatisfy({ $0 == " " || $0 == "\t" }) { continue }

            let lineNo = index + 1
            lastLine = lineNo

            // Indentation is the leading run of spaces/tabs.
            let indentWidth = line.prefix { $0 == " " || $0 == "\t" }.count
            if indentWidth > indentStack.last! {
                indentStack.append(indentWidth)
                tokens.append(Token(.indent, line: lineNo, column: 1))
            } else {
                while indentWidth < indentStack.last! {
                    indentStack.removeLast()
                    tokens.append(Token(.dedent, line: lineNo, column: 1))
                }
            }

            // Tokenize the rest of the line.
            var column = indentWidth + 1
            var i = line.index(line.startIndex, offsetBy: indentWidth)
            while i < line.endIndex {
                let c = line[i]
                switch c {
                case " ", "\t":
                    i = line.index(after: i)
                    column += 1
                case ".":
                    tokens.append(Token(.dot, line: lineNo, column: column))
                    i = line.index(after: i)
                    column += 1
                case "#":
                    tokens.append(Token(.hash, line: lineNo, column: column))
                    i = line.index(after: i)
                    column += 1
                default:
                    guard Lexer.isIdentifierStart(c) else {
                        throw LexError(message: "unexpected character '\(c)'", line: lineNo, column: column)
                    }
                    let startColumn = column
                    var text = ""
                    while i < line.endIndex, Lexer.isIdentifierPart(line[i]) {
                        text.append(line[i])
                        i = line.index(after: i)
                        column += 1
                    }
                    tokens.append(Token(.identifier(text), line: lineNo, column: startColumn))
                }
            }
            tokens.append(Token(.newline, line: lineNo, column: column))
        }

        // Close any blocks still open at end of input.
        while indentStack.last! > 0 {
            indentStack.removeLast()
            tokens.append(Token(.dedent, line: lastLine, column: 1))
        }
        tokens.append(Token(.eof, line: lastLine, column: 1))
        return tokens
    }

    // identifier ::= letter { letter | digit | "_" | "-" }   (ASCII, per the grammar)
    static func isIdentifierStart(_ c: Character) -> Bool {
        c.isASCII && c.isLetter
    }

    static func isIdentifierPart(_ c: Character) -> Bool {
        if c == "_" || c == "-" { return true }
        return c.isASCII && (c.isLetter || c.isNumber)
    }
}
