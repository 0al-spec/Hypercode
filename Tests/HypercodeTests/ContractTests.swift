import XCTest
@testable import Hypercode

// MARK: - CascadeSheetReader: @contract: parsing

final class ContractParsingTests: XCTestCase {
    private let reader = CascadeSheetReader()

    func testParsesContractBlock() throws {
        let src = """
        @contract:
          service:
            timeout: int >= 1 <= 300
            name: string
        """
        let sheet = try reader.read(src)
        XCTAssertEqual(sheet.contracts.count, 1)
        let sc = sheet.contracts[0]
        XCTAssertEqual(sc.selector, .type("service"))
        XCTAssertEqual(sc.properties["timeout"]?.type, .int)
        XCTAssertEqual(sc.properties["timeout"]?.min, 1)
        XCTAssertEqual(sc.properties["timeout"]?.max, 300)
        XCTAssertEqual(sc.properties["timeout"]?.required, true)
        XCTAssertEqual(sc.properties["name"]?.type, .string)
        XCTAssertEqual(sc.properties["name"]?.required, true)
    }

    func testParsesOptionalConstraint() throws {
        let src = """
        @contract:
          service:
            timeout[?]: int >= 1
        """
        let sheet = try reader.read(src)
        let sc = sheet.contracts[0]
        XCTAssertEqual(sc.properties["timeout"]?.required, false)
        XCTAssertEqual(sc.properties["timeout"]?.min, 1)
        XCTAssertNil(sc.properties["timeout"]?.max)
    }

    func testParsesMultipleContractSelectors() throws {
        let src = """
        @contract:
          service:
            timeout: int
          .primary:
            replicas: int >= 2
        """
        let sheet = try reader.read(src)
        XCTAssertEqual(sheet.contracts.count, 2)
        XCTAssertEqual(sheet.contracts[0].selector, .type("service"))
        XCTAssertEqual(sheet.contracts[1].selector, .klass("primary"))
    }

    func testParsesContractAlongsideRules() throws {
        let src = """
        service:
          timeout: 30

        @contract:
          service:
            timeout: int >= 1
        """
        let sheet = try reader.read(src)
        XCTAssertEqual(sheet.rules.count, 1)
        XCTAssertEqual(sheet.contracts.count, 1)
    }

    func testRejectsUnknownConstraintType() {
        let src = """
        @contract:
          service:
            x: colour
        """
        XCTAssertThrowsError(try reader.read(src))
    }
}

// MARK: - ContractValidator: monotonicity

final class ContractValidatorTests: XCTestCase {
    private let validator = ContractValidator()

    private func contract(_ selector: Hypercode.Selector,
                          _ properties: [String: PropertyContract],
                          line: Int = 1) -> SelectorContract {
        SelectorContract(selector: selector, properties: properties, line: line)
    }

    private func forest(_ source: String) -> [Command] {
        try! Parser(source: source).parse()
    }

    /// A document where `service` and `.primary` match the same node.
    private var overlapping: [Command] { forest("App\n  service.primary\n") }

    func testNoViolationIdenticalConstraints() {
        let less = contract(.type("service"), ["timeout": PropertyContract(type: .int, required: true, min: 1, max: 300)])
        let more = contract(.klass("primary"), ["timeout": PropertyContract(type: .int, required: true, min: 1, max: 300)])
        XCTAssertTrue(validator.validate([less, more], against: overlapping).isEmpty)
    }

    func testNoViolationMoreSpecificNarrows() {
        let less = contract(.type("service"), ["timeout": PropertyContract(type: .int, required: false, min: 1, max: 300)])
        let more = contract(.klass("primary"), ["timeout": PropertyContract(type: .int, required: true, min: 10, max: 200)])
        XCTAssertTrue(validator.validate([less, more], against: overlapping).isEmpty)
    }

    func testTypeMismatchHC2101() {
        let less = contract(.type("service"), ["timeout": PropertyContract(type: .int)])
        let more = contract(.klass("primary"), ["timeout": PropertyContract(type: .float)])
        let diags = validator.validate([less, more], against: overlapping)
        XCTAssertEqual(diags.count, 1)
        XCTAssertEqual(diags[0].code, "HC2101")
    }

    func testIntervalWideningLowerBoundHC2102() {
        let less = contract(.type("service"), ["timeout": PropertyContract(type: .int, min: 5)])
        let more = contract(.klass("primary"), ["timeout": PropertyContract(type: .int, min: 1)])
        let diags = validator.validate([less, more], against: overlapping)
        XCTAssertEqual(diags.count, 1)
        XCTAssertEqual(diags[0].code, "HC2102")
        XCTAssertTrue(diags[0].message.contains("lower bound"))
    }

    func testIntervalWideningUpperBoundHC2102() {
        let less = contract(.type("service"), ["timeout": PropertyContract(type: .int, max: 100)])
        let more = contract(.klass("primary"), ["timeout": PropertyContract(type: .int, max: 200)])
        let diags = validator.validate([less, more], against: overlapping)
        XCTAssertEqual(diags.count, 1)
        XCTAssertEqual(diags[0].code, "HC2102")
        XCTAssertTrue(diags[0].message.contains("upper bound"))
    }

    func testOptionalWeakeningHC2103() {
        let less = contract(.type("service"), ["name": PropertyContract(type: .string, required: true)])
        let more = contract(.klass("primary"), ["name": PropertyContract(type: .string, required: false)])
        let diags = validator.validate([less, more], against: overlapping)
        XCTAssertEqual(diags.count, 1)
        XCTAssertEqual(diags[0].code, "HC2103")
    }

    func testNoViolationUnsharedKeys() {
        let less = contract(.type("service"), ["timeout": PropertyContract(type: .int)])
        let more = contract(.klass("primary"), ["replicas": PropertyContract(type: .int)])
        XCTAssertTrue(validator.validate([less, more], against: overlapping).isEmpty)
    }

    // Review R3: specificity only relates contracts that can govern the same
    // node — disjoint selectors must not be compared.
    func testNoViolationDisjointSelectors() {
        let doc = forest("App\n  service\n  cache.slow\n")
        let a = contract(.type("service"), ["timeout": PropertyContract(type: .int, max: 100)])
        let b = contract(.klass("slow"), ["timeout": PropertyContract(type: .int, max: 500)])
        XCTAssertTrue(validator.validate([a, b], against: doc).isEmpty,
                      "selectors matching different nodes must not be related by specificity")
    }

    // Review R4: at equal specificity both contracts apply with equal force —
    // a type conflict makes the intersection unsatisfiable.
    func testEqualSpecificityTypeConflictHC2101() {
        let doc = forest("App\n  service\n")
        let a = contract(.type("service"), ["timeout": PropertyContract(type: .int)], line: 2)
        let b = contract(.type("service"), ["timeout": PropertyContract(type: .float)], line: 4)
        let diags = validator.validate([a, b], against: doc)
        XCTAssertEqual(diags.count, 1)
        XCTAssertEqual(diags[0].code, "HC2101")
        XCTAssertTrue(diags[0].message.contains("equal specificity"))
    }

    func testEqualSpecificityCompatibleContractsAreClean() {
        let doc = forest("App\n  service\n")
        let a = contract(.type("service"), ["timeout": PropertyContract(type: .int, max: 100)])
        let b = contract(.type("service"), ["timeout": PropertyContract(type: .int, max: 200)])
        XCTAssertTrue(validator.validate([a, b], against: doc).isEmpty,
                      "same type at equal specificity intersects fine — bounds intersect, not conflict")
    }
}

// MARK: - Validator integration

final class ValidatorContractIntegrationTests: XCTestCase {
    func testValidatorRunsContractChecks() throws {
        let src = """
        @contract:
          service:
            timeout: int
          .primary:
            timeout: float
        """
        let sheet = try CascadeSheetReader().read(src)
        let doc = try Parser(source: "App\n  service.primary\n").parse()
        let diags = Validator().validate(sheet, against: doc)
        XCTAssertTrue(diags.map(\.code).contains("HC2101"))
    }
}
