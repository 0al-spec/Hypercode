import XCTest
@testable import Hypercode

final class GrammarSpecTests: XCTestCase {
    func testCommandSpec() {
        let spec = CommandSpec()
        XCTAssertTrue(spec.isSatisfiedBy("Application"))
        XCTAssertTrue(spec.isSatisfiedBy("Button.primary"))
        XCTAssertTrue(spec.isSatisfiedBy("Button#ok"))
        XCTAssertTrue(spec.isSatisfiedBy("Button.primary#ok"))
        XCTAssertFalse(spec.isSatisfiedBy(""))
        XCTAssertFalse(spec.isSatisfiedBy(".primaryButton"))     // class first, no type
        XCTAssertFalse(spec.isSatisfiedBy("Button#ok.primary"))  // id before class
        XCTAssertFalse(spec.isSatisfiedBy("Button.a.b"))         // two classes
        XCTAssertFalse(spec.isSatisfiedBy("123Button"))          // invalid identifier
    }

    func testLineSpecs() {
        XCTAssertTrue(IsBlankLineSpec().isSatisfiedBy(RawLine(number: 1, text: "   ")))
        XCTAssertFalse(IsBlankLineSpec().isSatisfiedBy(RawLine(number: 1, text: "  App")))

        XCTAssertTrue(IsCommandLineSpec().isSatisfiedBy(RawLine(number: 1, text: "  App")))
        XCTAssertFalse(IsCommandLineSpec().isSatisfiedBy(RawLine(number: 1, text: "")))

        XCTAssertTrue(ValidCommandLineSpec().isSatisfiedBy(RawLine(number: 1, text: "  Button.primary#ok")))
        XCTAssertFalse(ValidCommandLineSpec().isSatisfiedBy(RawLine(number: 1, text: "   ")))
        XCTAssertFalse(ValidCommandLineSpec().isSatisfiedBy(RawLine(number: 1, text: ".bad")))
    }

    func testLineKindDecision() {
        let decision = LineKindDecision()
        XCTAssertEqual(decision.decide(RawLine(number: 1, text: "")), .blank)
        XCTAssertEqual(decision.decide(RawLine(number: 1, text: "  ")), .blank)
        XCTAssertEqual(decision.decide(RawLine(number: 1, text: "App")), .command)
    }
}
