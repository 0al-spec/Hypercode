import XCTest
@testable import Hypercode

final class SpecificationTests: XCTestCase {
    func testIdentifierSpec() {
        let spec = IdentifierSpec()
        XCTAssertTrue(spec.isSatisfiedBy("App"))
        XCTAssertTrue(spec.isSatisfiedBy("primary-db"))
        XCTAssertTrue(spec.isSatisfiedBy("a_1"))
        XCTAssertFalse(spec.isSatisfiedBy(""))
        XCTAssertFalse(spec.isSatisfiedBy("123Button")) // must start with a letter
        XCTAssertFalse(spec.isSatisfiedBy(".dot"))       // '.' is not an identifier char
    }
}
