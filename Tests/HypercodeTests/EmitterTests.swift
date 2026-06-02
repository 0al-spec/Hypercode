import XCTest
@testable import Hypercode

final class EmitterTests: XCTestCase {
    private func sample() throws -> [ResolvedNode] {
        let forest = try Parser(source: "App\n  Button.primary#ok\n").parse()
        let sheet = try CascadeSheetReader().read("Button:\n  label: \"Go\"\n")
        return Resolver(sheet: sheet).resolve(forest)
    }

    func testJSONEmit() throws {
        let json = Emitter().emit(try sample(), as: .json)
        XCTAssertTrue(json.contains("\"version\": \"hypercode.ir/v1\""))
        XCTAssertTrue(json.contains("\"type\": \"App\""))
        XCTAssertTrue(json.contains("\"class\": \"primary\""))
        XCTAssertTrue(json.contains("\"id\": \"ok\""))
        XCTAssertTrue(json.contains("\"value\": \"Go\""))
        XCTAssertTrue(json.contains("\"from\": \"Button\""))
        XCTAssertTrue(json.hasSuffix("}\n"))
    }

    func testYAMLEmit() throws {
        let yaml = Emitter().emit(try sample(), as: .yaml)
        XCTAssertTrue(yaml.contains("version: hypercode.ir/v1"))
        XCTAssertTrue(yaml.contains("type: App"))
        XCTAssertTrue(yaml.contains("label:"))
        XCTAssertTrue(yaml.contains("value: Go"))
        XCTAssertTrue(yaml.contains("from: Button"))
    }
}
