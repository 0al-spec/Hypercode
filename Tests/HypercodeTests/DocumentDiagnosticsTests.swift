import XCTest
@testable import Hypercode

final class DocumentDiagnosticsTests: XCTestCase {
    func testKindFromPath() {
        XCTAssertEqual(DocumentKind(path: "a.hcs"), .cascadeSheet)
        XCTAssertEqual(DocumentKind(path: "a.hc"), .hypercode)
        XCTAssertEqual(DocumentKind(path: "noext"), .hypercode)
    }

    func testHypercodeDocumentParseError() {
        let result = diagnostics(for: .hypercode, text: ".bad\n")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.code, "HC1101")
    }

    func testHypercodeDocumentValidationWarning() {
        let result = diagnostics(for: .hypercode, text: "A#x\nB#x\n")
        XCTAssertEqual(result.first?.code, "HC3001")
    }

    func testCascadeSheetDocumentError() {
        let result = diagnostics(for: .cascadeSheet, text: "123Bad:\n  x: 1\n")
        XCTAssertEqual(result.first?.code, "HC2001")
    }

    func testCleanDocumentHasNoDiagnostics() {
        XCTAssertTrue(diagnostics(for: .hypercode, text: "App\n  Button\n").isEmpty)
    }
}
