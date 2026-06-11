import XCTest
@testable import Hypercode

/// HC2104 — resolved values checked against the contracts governing each node.
final class ContractValueTests: XCTestCase {
    private func diagnostics(
        hc: String, hcs: String, context: ResolutionContext = [:]
    ) throws -> [Diagnostic] {
        let forest = try Parser(source: hc).parse()
        let sheet = try CascadeSheetReader().read(hcs)
        let resolved = Resolver(sheet: sheet, context: context).resolve(forest)
        return ContractValueValidator().validate(
            resolved: resolved, commands: forest, contracts: sheet.contracts
        )
    }

    func testUpperBoundViolation() throws {
        let diags = try diagnostics(
            hc: "App\n  service\n",
            hcs: """
            service:
              timeout: 999

            @contract:
              service:
                timeout: int <= 300
            """
        )
        XCTAssertEqual(diags.count, 1)
        XCTAssertEqual(diags[0].code, "HC2104")
        XCTAssertTrue(diags[0].message.contains("exceeds upper bound"))
    }

    func testLowerBoundViolation() throws {
        let diags = try diagnostics(
            hc: "App\n  service\n",
            hcs: """
            service:
              replicas: 1

            @contract:
              service:
                replicas: int >= 2
            """
        )
        XCTAssertEqual(diags.count, 1)
        XCTAssertTrue(diags[0].message.contains("below lower bound"))
    }

    func testTypeMismatch() throws {
        let diags = try diagnostics(
            hc: "App\n  service\n",
            hcs: """
            service:
              timeout: fast

            @contract:
              service:
                timeout: int
            """
        )
        XCTAssertEqual(diags.count, 1)
        XCTAssertEqual(diags[0].code, "HC2104")
        XCTAssertTrue(diags[0].message.contains("does not satisfy type 'int'"))
    }

    func testMissingRequiredProperty() throws {
        let diags = try diagnostics(
            hc: "App\n  service\n",
            hcs: """
            @contract:
              service:
                timeout: int
            """
        )
        XCTAssertEqual(diags.count, 1)
        XCTAssertTrue(diags[0].message.contains("missing required property 'timeout'"))
        XCTAssertTrue(diags[0].message.contains("'service'"))
    }

    func testMissingOptionalPropertyIsClean() throws {
        let diags = try diagnostics(
            hc: "App\n  service\n",
            hcs: """
            @contract:
              service:
                timeout[?]: int
            """
        )
        XCTAssertTrue(diags.isEmpty)
    }

    func testValueWithinBoundsIsClean() throws {
        let diags = try diagnostics(
            hc: "App\n  service\n",
            hcs: """
            service:
              timeout: 30

            @contract:
              service:
                timeout: int >= 1 <= 300
            """
        )
        XCTAssertTrue(diags.isEmpty)
    }

    func testIntersectionOfAccumulatedContracts() throws {
        // service caps at 300; .primary raises the floor to 10.
        // A value of 5 satisfies the service contract but violates .primary's.
        let diags = try diagnostics(
            hc: "App\n  service.primary\n",
            hcs: """
            service:
              timeout: 5

            @contract:
              service:
                timeout: int <= 300
              .primary:
                timeout: int >= 10
            """
        )
        XCTAssertEqual(diags.count, 1)
        XCTAssertTrue(diags[0].message.contains("below lower bound 10.0 from contract '.primary'"))
    }

    func testIntSatisfiesFloatContract() throws {
        let diags = try diagnostics(
            hc: "App\n  service\n",
            hcs: """
            service:
              ratio: 2

            @contract:
              service:
                ratio: float >= 0.5
            """
        )
        XCTAssertTrue(diags.isEmpty, "an int value satisfies a float contract")
    }

    func testContextDependentViolation() throws {
        let hc = "App\n  service\n"
        let hcs = """
        service:
          timeout: 30

        @env[production]:
          service:
            timeout: 999

        @contract:
          service:
            timeout: int <= 300
        """
        let dev = try diagnostics(hc: hc, hcs: hcs)
        XCTAssertTrue(dev.isEmpty, "development context resolves to 30 — clean")

        let prod = try diagnostics(hc: hc, hcs: hcs, context: ["env": "production"])
        XCTAssertEqual(prod.count, 1, "production context resolves to 999 — violation")
        XCTAssertEqual(prod[0].code, "HC2104")
    }

    func testViolationPointsAtWinningRule() throws {
        let diags = try diagnostics(
            hc: "App\n  service\n",
            hcs: """
            service:
              timeout: 999

            @contract:
              service:
                timeout: int <= 300
            """
        )
        // Provenance records the winning rule's header line (line 1: "service:"),
        // consistent with v1 IR "line" — not the property line within the block.
        XCTAssertEqual(diags[0].range?.start.line, 1,
                       "diagnostic points at the winning rule, not the contract declaration")
    }
}
