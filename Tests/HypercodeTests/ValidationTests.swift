import XCTest
@testable import Hypercode

final class ValidationTests: XCTestCase {
    func testDuplicateIdIsAnError() throws {
        let forest = try Parser(source: "A#x\nB#x\n").parse()
        let diagnostics = Validator().validate(forest)
        XCTAssertEqual(diagnostics.count, 1)
        XCTAssertEqual(diagnostics.first?.severity, .error)
    }

    func testUniqueIdsAreClean() throws {
        let forest = try Parser(source: "A#x\nB#y\n").parse()
        XCTAssertTrue(Validator().validate(forest).isEmpty)
    }

    func testDanglingSelectorIsAWarning() throws {
        let forest = try Parser(source: "App\n  Button\n").parse()
        let sheet = try CascadeSheetReader().read("Nonexistent:\n  k: v\n")
        let diagnostics = Validator().validate(sheet, against: forest)
        XCTAssertEqual(diagnostics.count, 1)
        XCTAssertEqual(diagnostics.first?.severity, .warning)
    }

    func testMatchingSelectorIsClean() throws {
        let forest = try Parser(source: "App\n  Button\n").parse()
        let sheet = try CascadeSheetReader().read("Button:\n  k: v\n")
        XCTAssertTrue(Validator().validate(sheet, against: forest).isEmpty)
    }
}
