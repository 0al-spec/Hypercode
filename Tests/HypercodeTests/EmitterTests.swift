import XCTest
@testable import Hypercode

final class EmitterTests: XCTestCase {
    private func sample() throws -> [ResolvedNode] {
        let forest = try Parser(source: "App\n  Button.primary#ok\n").parse()
        let sheet = try CascadeSheetReader().read("Button:\n  label: \"Go\"\n")
        return Resolver(sheet: sheet).resolve(forest)
    }

    // MARK: v1 (legacy)

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

    // MARK: v2

    func testV2JSONStructure() throws {
        let forest = try Parser(source: "App\n  Button.primary#ok\n").parse()
        let sheet = try CascadeSheetReader().read(
            "Button:\n  count: 3\n  active: true\n  label: \"Go\"\n"
        )
        let resolved = Resolver(sheet: sheet).resolve(forest)
        let json = Emitter().emit(resolved, version: .v2, context: ["env": "test"], as: .json)

        XCTAssertTrue(json.contains("\"version\": \"hypercode.ir/v2\""))
        XCTAssertTrue(json.contains("\"env\": \"test\""))
        XCTAssertTrue(json.contains("\"name\": \"hypercode-swift\""))
        XCTAssertTrue(json.contains("\"documentHash\""))
        XCTAssertTrue(json.contains("\"hash\""))

        // Typed values: int, bool, string
        XCTAssertTrue(json.contains("\"value\": 3"))
        XCTAssertTrue(json.contains("\"value\": true"))
        XCTAssertTrue(json.contains("\"value\": \"Go\""))

        // winner/losers/contracts present
        XCTAssertTrue(json.contains("\"winner\""))
        XCTAssertTrue(json.contains("\"losers\""))
        XCTAssertTrue(json.contains("\"contracts\""))

        // documentHash is a 64-char hex string
        let hashRange = json.range(of: #""documentHash": "[0-9a-f]{64}""#,
                                   options: .regularExpression)
        XCTAssertNotNil(hashRange)
    }

    func testV2EveryNodeCarriesAHash() throws {
        // Regression (review R1): child nodes used to miss the schema-required
        // "hash" field — it was only post-inserted into root nodes.
        let forest = try Parser(source: "App\n  Service\n    Database\n").parse()
        let sheet = try CascadeSheetReader().read("Service:\n  timeout: 30\n")
        let resolved = Resolver(sheet: sheet).resolve(forest)
        let json = Emitter().emit(resolved, version: .v2, as: .json)

        let hashCount = json.components(separatedBy: "\"hash\": \"").count - 1
        XCTAssertEqual(hashCount, 3, "all three nodes (App, Service, Database) must carry a hash")
    }

    func testV2HugeNumberDoesNotCrash() throws {
        // Regression (review R2): a numeral beyond Int.max parses as Double and
        // used to trap in Int(_:) inside the whole-number JSON branch.
        let forest = try Parser(source: "App\n").parse()
        let sheet = try CascadeSheetReader().read("App:\n  huge: 99999999999999999999999999\n")
        let resolved = Resolver(sheet: sheet).resolve(forest)
        let json = Emitter().emit(resolved, version: .v2, as: .json)
        XCTAssertTrue(json.contains("1e+26"), "huge double must render in scientific notation")
    }

    func testV2ContractsSortedBySpecificityAscending() throws {
        // Review R8: contracts[] must accumulate narrowest-last.
        let forest = try Parser(source: "App\n  Service.primary\n").parse()
        let sheet = try CascadeSheetReader().read("""
        Service:
          timeout: 30

        @contract:
          .primary:
            timeout: int <= 200
          Service:
            timeout: int <= 300
        """)
        let resolved = Resolver(sheet: sheet).resolve(forest)
        let json = Emitter().emit(
            resolved, version: .v2, commands: forest, contracts: sheet.contracts, as: .json
        )
        // Compare positions inside the contracts array only — the winner entry
        // also carries a "selector" key and must not skew the check.
        guard let contractsStart = json.range(of: "\"contracts\": [") else {
            return XCTFail("contracts array must be present")
        }
        let tail = json[contractsStart.upperBound...]
        guard let serviceRange = tail.range(of: #""selector": "Service""#),
              let classRange = tail.range(of: #""selector": ".primary""#) else {
            return XCTFail("both contracts must appear in the IR")
        }
        XCTAssertTrue(serviceRange.lowerBound < classRange.lowerBound,
                      "ascending specificity: Service (0,0,1) before .primary (0,1,0)")
    }

    func testV2HashChangesWhenValueChanges() throws {
        let hc = "App\n"
        let hcsA = "App:\n  x: 1\n"
        let hcsB = "App:\n  x: 2\n"

        func emit(_ hcs: String) throws -> String {
            let forest = try Parser(source: hc).parse()
            let sheet = try CascadeSheetReader().read(hcs)
            let resolved = Resolver(sheet: sheet).resolve(forest)
            return Emitter().emit(resolved, version: .v2, as: .json)
        }

        let jsonA = try emit(hcsA)
        let jsonB = try emit(hcsB)
        XCTAssertNotEqual(jsonA, jsonB, "different resolved values must produce different hashes")

        // Same content → identical hashes (determinism)
        let jsonA2 = try emit(hcsA)
        XCTAssertEqual(jsonA, jsonA2, "repeated emit of same input must produce identical output")
    }

    func testV2JSONEscapesObjectKeys() throws {
        // The CLI gates --ctx keys to identifiers, but a library consumer can
        // pass any string — keys must be escaped exactly like string values.
        let forest = try Parser(source: "App\n").parse()
        let resolved = Resolver(sheet: CascadeSheet(rules: [])).resolve(forest)
        let json = Emitter().emit(
            resolved, version: .v2, context: ["bad\"key\\name": "x\"y"], as: .json
        )
        XCTAssertTrue(json.contains(#""bad\"key\\name": "x\"y""#),
                      "context key and value must be JSON-escaped:\n\(json)")
        XCTAssertFalse(json.contains("bad\"key"), "raw quote must not survive in a key")
    }
}
