import XCTest
@testable import Hypercode

final class LexerTests: XCTestCase {
    private func kinds(_ source: String) throws -> [Token.Kind] {
        try Lexer(source).tokenize().map(\.kind)
    }

    func testSimpleCommand() throws {
        XCTAssertEqual(
            try kinds("App\n"),
            [.identifier("App"), .newline, .eof]
        )
    }

    func testClassAndId() throws {
        XCTAssertEqual(
            try kinds("Button.primary#ok\n"),
            [.identifier("Button"), .dot, .identifier("primary"),
             .hash, .identifier("ok"), .newline, .eof]
        )
    }

    func testIndentThenDedent() throws {
        XCTAssertEqual(
            try kinds("App\n  Child\n"),
            [.identifier("App"), .newline,
             .indent, .identifier("Child"), .newline,
             .dedent, .eof]
        )
    }

    func testBlankLinesAreSkipped() throws {
        XCTAssertEqual(
            try kinds("A\n\n  B\n\n"),
            [.identifier("A"), .newline,
             .indent, .identifier("B"), .newline,
             .dedent, .eof]
        )
    }

    func testInvalidIdentifierStartThrows() {
        XCTAssertThrowsError(try Lexer("123Button\n").tokenize())
    }

    func testInconsistentDedentThrows() {
        // `   Weird` (3 spaces) dedents to a column that was never indented.
        XCTAssertThrowsError(try Lexer("App\n  Child\n    Grand\n   Weird\n").tokenize())
    }
}
