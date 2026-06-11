import XCTest
@testable import Hypercode

final class HCSReaderTests: XCTestCase {
    private func read(_ lines: [String]) throws -> CascadeSheet {
        try CascadeSheetReader().read(lines.joined(separator: "\n") + "\n")
    }

    func testGlobalRulesAndProperties() throws {
        let sheet = try read([
            "Database:",
            "  driver: \"sqlite\"",
            "  in_memory: true",
            ".pooled:",
            "  pool_size: 20",
        ])

        XCTAssertEqual(sheet.rules.count, 2)
        XCTAssertEqual(sheet.rules[0].selector, .type("Database"))
        XCTAssertNil(sheet.rules[0].condition)
        XCTAssertEqual(sheet.rules[0].properties["driver"], .string("sqlite"))   // quotes stripped
        XCTAssertEqual(sheet.rules[0].properties["in_memory"], .bool(true))
        XCTAssertEqual(sheet.rules[1].selector, .klass("pooled"))
        XCTAssertEqual(sheet.rules[1].properties["pool_size"], .int(20))
    }

    func testContextBlockChildAndIdSelectors() throws {
        let sheet = try read([
            "@env[production]:",
            "  '#primary-db':",
            "    host: \"override.db\"",
            "  WebServer > Listen:",
            "    port: 80",
        ])

        XCTAssertEqual(sheet.rules.count, 2)

        let idRule = sheet.rules[0]
        XCTAssertEqual(idRule.selector, .id("primary-db"))
        XCTAssertEqual(idRule.condition, ContextGuard(dimension: "env", value: "production"))
        XCTAssertEqual(idRule.properties["host"], .string("override.db"))

        let childRule = sheet.rules[1]
        XCTAssertEqual(childRule.selector, .child(.type("WebServer"), .type("Listen")))
        XCTAssertEqual(childRule.properties["port"], .int(80))
    }

    func testInvalidSelectorThrows() {
        XCTAssertThrowsError(try read(["123Bad:", "  x: 1"]))
    }

    func testCommentsAreSkipped() throws {
        let sheet = try read([
            "# a comment",
            "Database:",
            "  driver: \"x\"",
            "# --- section ---",
            ".pooled:",
            "  size: 10",
        ])
        XCTAssertEqual(sheet.rules.count, 2)
        XCTAssertEqual(sheet.rules[0].selector, .type("Database"))
        XCTAssertEqual(sheet.rules[1].selector, .klass("pooled"))
    }

    func testQuotedScalarsStayStrings() throws {
        // Quoting forces string — numeric-looking and boolean-looking literals
        // must not be type-inferred, and leading zeros must survive.
        let sheet = try read([
            "Service:",
            "  zip: \"00123\"",
            "  flag: 'false'",
            "  port: 8080",
            "  active: true",
        ])
        let props = sheet.rules[0].properties
        XCTAssertEqual(props["zip"], .string("00123"))
        XCTAssertEqual(props["flag"], .string("false"))
        XCTAssertEqual(props["port"], .int(8080))
        XCTAssertEqual(props["active"], .bool(true))
    }

    func testTypedValueInterpolatesAsScalarText() {
        // The resolve tree rendering interpolates values directly; the enum
        // must print scalar text, not its case spelling.
        XCTAssertEqual("\(TypedValue.int(5000))", "5000")
        XCTAssertEqual("\(TypedValue.bool(true))", "true")
        XCTAssertEqual("\(TypedValue.string("debug"))", "debug")
    }
}
