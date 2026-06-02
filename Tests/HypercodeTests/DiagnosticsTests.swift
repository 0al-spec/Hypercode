import XCTest
@testable import Hypercode

final class DiagnosticsTests: XCTestCase {
    func testParseErrorBecomesDiagnostic() {
        do {
            _ = try Parser(source: ".bad\n").parse()
            XCTFail("expected a parse error")
        } catch let error as DiagnosticConvertible {
            let d = error.diagnostic(file: "app.hc")
            XCTAssertEqual(d.severity, .error)
            XCTAssertEqual(d.code, "HC1101")
            XCTAssertEqual(d.file, "app.hc")
            XCTAssertNotNil(d.range)
        } catch {
            XCTFail("expected DiagnosticConvertible, got \(error)")
        }
    }

    func testLexErrorBecomesDiagnostic() {
        XCTAssertThrowsError(try Lexer("123Bad\n").tokenize()) { error in
            guard let convertible = error as? DiagnosticConvertible else {
                return XCTFail("expected DiagnosticConvertible")
            }
            XCTAssertEqual(convertible.diagnostic(file: nil).code, "HC1001")
        }
    }

    func testTextRendering() {
        let d = Diagnostic(
            severity: .error, code: "HC1101", message: "boom",
            file: "app.hc", range: SourceRange(SourcePosition(line: 3, column: 5))
        )
        XCTAssertEqual(d.renderedText(), "app.hc:3:5: error[HC1101]: boom")
    }

    func testJSONRenderingIsLSPShaped() {
        let d = Diagnostic(
            severity: .warning, code: "HC3002", message: "x",
            file: "a.hcs", range: SourceRange(SourcePosition(line: 2, column: 4))
        )
        let json = DiagnosticsRenderer.render([d], as: .json)
        XCTAssertTrue(json.contains("\"line\":1"))        // 0-based line
        XCTAssertTrue(json.contains("\"character\":3"))   // 0-based column
        XCTAssertTrue(json.contains("\"severity\":2"))    // LSP warning
        XCTAssertTrue(json.contains("\"code\":\"HC3002\""))
        XCTAssertTrue(json.contains("\"source\":\"hypercode\""))
    }

    func testValidatorDiagnosticsAreCoded() throws {
        let forest = try Parser(source: "A#x\nB#x\n").parse()
        let diagnostics = Validator().validate(forest)
        XCTAssertEqual(diagnostics.first?.code, "HC3001")
        XCTAssertEqual(diagnostics.first?.severity, .error)
    }
}
