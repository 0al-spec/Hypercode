import XCTest
@testable import Hypercode

/// Cases ported from `EBNF/hypercode_tests/*.hc` (the reference ANTLR suite).
final class ParserTests: XCTestCase {
    private func parse(_ source: String) throws -> [Command] {
        try Parser(source: source).parse()
    }

    // 01-basic.hc
    func testBasicSiblings() throws {
        XCTAssertEqual(
            try parse("Application\nButton\nCancel\n"),
            [
                Command(type: "Application"),
                Command(type: "Button"),
                Command(type: "Cancel"),
            ]
        )
    }

    // 02-class-id.hc
    func testClassAndId() throws {
        XCTAssertEqual(
            try parse("Application\n  Button.primary#ok\n  Button.secondary#cancel\n"),
            [
                Command(type: "Application", children: [
                    Command(type: "Button", className: "primary", id: "ok"),
                    Command(type: "Button", className: "secondary", id: "cancel"),
                ]),
            ]
        )
    }

    // 03-nesting.hc
    func testNesting() throws {
        let source = "Application\n"
            + "  Form\n"
            + "    Input.text#name\n"
            + "    Input.password#pass\n"
            + "  Button.primary#submit\n"
        XCTAssertEqual(
            try parse(source),
            [
                Command(type: "Application", children: [
                    Command(type: "Form", children: [
                        Command(type: "Input", className: "text", id: "name"),
                        Command(type: "Input", className: "password", id: "pass"),
                    ]),
                    Command(type: "Button", className: "primary", id: "submit"),
                ]),
            ]
        )
    }

    // 04-empty-lines.hc
    func testEmptyLinesIgnored() throws {
        XCTAssertEqual(
            try parse("Application\n\n  Button.primary#confirm\n\n\n  Cancel\n"),
            [
                Command(type: "Application", children: [
                    Command(type: "Button", className: "primary", id: "confirm"),
                    Command(type: "Cancel"),
                ]),
            ]
        )
    }

    // 07-bad-indent.hc — a single deeper indent is structurally valid.
    func testDeeperIndentIsOneLevel() throws {
        XCTAssertEqual(
            try parse("Application\n    Button\n"),
            [Command(type: "Application", children: [Command(type: "Button")])]
        )
    }

    // 08-id-or-class-ok.hc
    func testIdOrClassAlone() throws {
        XCTAssertEqual(
            try parse("Button#onlyId\nButton.primary\n"),
            [
                Command(type: "Button", id: "onlyId"),
                Command(type: "Button", className: "primary"),
            ]
        )
    }

    // 09-sibling-blocks.hc
    func testSiblingBlocks() throws {
        XCTAssertEqual(
            try parse("Section\n  Title\n  Paragraph\n\nSection\n  Image\n"),
            [
                Command(type: "Section", children: [
                    Command(type: "Title"),
                    Command(type: "Paragraph"),
                ]),
                Command(type: "Section", children: [Command(type: "Image")]),
            ]
        )
    }

    // 10-indent-dedent.hc
    func testIndentDedentSiblings() throws {
        XCTAssertEqual(
            try parse("App\n  Form\n    Input\n  Button\n"),
            [
                Command(type: "App", children: [
                    Command(type: "Form", children: [Command(type: "Input")]),
                    Command(type: "Button"),
                ]),
            ]
        )
    }

    // 06-invalid-class-first.hc — a command must start with an identifier.
    func testClassFirstIsRejected() {
        XCTAssertThrowsError(try parse(".primaryButton\n"))
    }

    // X05-invalid-id.hc — an identifier must start with a letter.
    func testInvalidIdentifierIsRejected() {
        XCTAssertThrowsError(try parse("123Button\n"))
    }
}
