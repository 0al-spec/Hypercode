import XCTest
import Foundation
@testable import Hypercode

/// The white-label scenario: one `.hc` structure, swap the context to produce
/// a different build, without touching the structure. Reads the committed
/// `Examples/whitelabel/*` files so the example and the test cannot drift.
final class WhiteLabelTests: XCTestCase {
    private func example(_ name: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // HypercodeTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // swift
        return try String(contentsOf: root.appendingPathComponent("Examples/whitelabel/\(name)"), encoding: .utf8)
    }

    private func resolve(client: String?) throws -> [ResolvedNode] {
        let forest = try Parser(source: try example("app.hc")).parse()
        let sheet = try CascadeSheetReader().read(try example("brand.hcs"))
        let context: ResolutionContext = client.map { ["client": $0] } ?? [:]
        return Resolver(sheet: sheet, context: context).resolve(forest)
    }

    private func find(_ type: String, in forest: [ResolvedNode]) -> ResolvedNode? {
        for node in forest {
            if node.type == type { return node }
            if let found = find(type, in: node.children) { return found }
        }
        return nil
    }

    func testBrandsDifferWithoutTouchingStructure() throws {
        let acme = try resolve(client: "acme")
        let globex = try resolve(client: "globex")

        XCTAssertEqual(find("Logo", in: acme)?.properties["asset"]?.value, .string("logos/acme.svg"))
        XCTAssertEqual(find("Logo", in: globex)?.properties["asset"]?.value, .string("logos/globex.svg"))
        XCTAssertEqual(find("Api", in: acme)?.properties["base_url"]?.value, .string("https://api.acme.example"))
        XCTAssertEqual(find("Api", in: globex)?.properties["base_url"]?.value, .string("https://api.globex.example"))
    }

    func testDefaultsWhenNoClient() throws {
        let base = try resolve(client: nil)
        XCTAssertEqual(find("Logo", in: base)?.properties["asset"]?.value, .string("logos/default.svg"))
        XCTAssertEqual(find("Api", in: base)?.properties["base_url"]?.value, .string("https://api.default.example"))
    }
}
