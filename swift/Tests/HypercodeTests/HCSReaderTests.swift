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
        XCTAssertEqual(sheet.rules[0].properties["driver"], "sqlite")   // quotes stripped
        XCTAssertEqual(sheet.rules[0].properties["in_memory"], "true")
        XCTAssertEqual(sheet.rules[1].selector, .klass("pooled"))
        XCTAssertEqual(sheet.rules[1].properties["pool_size"], "20")
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
        XCTAssertEqual(idRule.properties["host"], "override.db")

        let childRule = sheet.rules[1]
        XCTAssertEqual(childRule.selector, .child(.type("WebServer"), .type("Listen")))
        XCTAssertEqual(childRule.properties["port"], "80")
    }

    func testInvalidSelectorThrows() {
        XCTAssertThrowsError(try read(["123Bad:", "  x: 1"]))
    }
}
