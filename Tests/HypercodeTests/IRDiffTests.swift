import XCTest
@testable import Hypercode

/// HC-113 — `hypercode diff` over IR v2 documents.
/// End-to-end: real sheets are resolved, emitted, parsed back and diffed.
final class IRDiffTests: XCTestCase {
    private func document(
        hc: String, hcs: String, context: ResolutionContext = [:]
    ) throws -> IRDocument {
        let commands = try Parser(source: hc).parse()
        let sheet = try CascadeSheetReader().read(hcs)
        let resolved = Resolver(sheet: sheet, context: context).resolve(commands)
        let json = Emitter().emit(
            resolved, version: .v2, context: context,
            commands: commands, contracts: sheet.contracts, as: .json
        )
        return try IRDocument(json: JSONParser.parse(json))
    }

    private let hc = "App\n  Service\n    Listen\n  Cache\n"
    private let hcs = "Service:\n  timeout: 30\nListen:\n  port: 5000\nCache:\n  size: 100\n"

    // MARK: - Diff semantics

    func testSelfDiffIsEmpty() throws {
        let doc = try document(hc: hc, hcs: hcs)
        XCTAssertEqual(IRDiffer().diff(old: doc, new: doc), [])
    }

    func testValueChangeReportedWithBothWinners() throws {
        let old = try document(hc: hc, hcs: hcs)
        let new = try document(hc: hc, hcs: hcs.replacingOccurrences(of: "port: 5000", with: "port: 9090"))
        let changes = IRDiffer().diff(old: old, new: new)

        XCTAssertEqual(changes.count, 1, "only the Listen node changed: \(changes)")
        guard case let .nodeModified(path, properties) = changes[0] else {
            return XCTFail("expected nodeModified, got \(changes[0])")
        }
        XCTAssertEqual(path, "App > Service > Listen")
        XCTAssertEqual(properties.count, 1)
        XCTAssertEqual(properties[0].key, "port")
        guard case let .changed(oldValue, newValue, oldWinner, newWinner) = properties[0].kind else {
            return XCTFail("expected changed kind")
        }
        XCTAssertEqual(oldValue, "5000")
        XCTAssertEqual(newValue, "9090")
        XCTAssertTrue(oldWinner.contains("Listen"))
        XCTAssertTrue(newWinner.contains("Listen"))
    }

    func testUnchangedSiblingSubtreeNotReported() throws {
        // Cache is untouched by the edit — hash short-circuit must skip it.
        let old = try document(hc: hc, hcs: hcs)
        let new = try document(hc: hc, hcs: hcs.replacingOccurrences(of: "timeout: 30", with: "timeout: 60"))
        let changes = IRDiffer().diff(old: old, new: new)
        XCTAssertFalse(changes.contains { change in
            if case let .nodeModified(path, _) = change { return path.contains("Cache") }
            if case let .nodeAdded(path) = change { return path.contains("Cache") }
            if case let .nodeRemoved(path) = change { return path.contains("Cache") }
            return false
        })
    }

    func testNodeAddedAndRemoved() throws {
        let old = try document(hc: "App\n  Service\n  LegacyQueue\n", hcs: "Service:\n  x: 1\n")
        let new = try document(hc: "App\n  Service\n  Cache\n", hcs: "Service:\n  x: 1\n")
        let changes = IRDiffer().diff(old: old, new: new)
        XCTAssertTrue(changes.contains(.nodeAdded(path: "App > Cache")))
        XCTAssertTrue(changes.contains(.nodeRemoved(path: "App > LegacyQueue")))
    }

    func testPropertyAddedAndRemoved() throws {
        let old = try document(hc: "App\n  Service\n", hcs: "Service:\n  timeout: 30\n  legacy: x\n")
        let new = try document(hc: "App\n  Service\n", hcs: "Service:\n  timeout: 30\n  retries: 3\n")
        let changes = IRDiffer().diff(old: old, new: new)
        guard case let .nodeModified(_, properties)? = changes.first, changes.count == 1 else {
            return XCTFail("expected a single nodeModified, got \(changes)")
        }
        XCTAssertEqual(properties.map(\.key), ["legacy", "retries"])
        guard case .removed = properties[0].kind, case .added = properties[1].kind else {
            return XCTFail("expected removed + added, got \(properties)")
        }
    }

    func testProvenanceOnlyChangeIsInvisible() throws {
        // A later duplicate rule wins with the same value — provenance changes,
        // the stable content does not, so hashes (and the diff) are unchanged.
        let old = try document(hc: "App\n  Service\n", hcs: "Service:\n  timeout: 30\n")
        let new = try document(hc: "App\n  Service\n", hcs: "Service:\n  timeout: 30\nService:\n  timeout: 30\n")
        XCTAssertEqual(old.documentHash, new.documentHash)
        XCTAssertEqual(IRDiffer().diff(old: old, new: new), [])
    }

    func testReorderedChildrenReported() throws {
        let old = try document(hc: "App\n  Service\n  Cache\n", hcs: "Service:\n  x: 1\n")
        let new = try document(hc: "App\n  Cache\n  Service\n", hcs: "Service:\n  x: 1\n")
        let changes = IRDiffer().diff(old: old, new: new)
        XCTAssertEqual(changes, [.childrenReordered(path: "App")])
    }

    func testNodeIdentityByClassAndId() throws {
        // Same type, different id → not the same node.
        let old = try document(hc: "App\n  Database#primary\n", hcs: "")
        let new = try document(hc: "App\n  Database#replica\n", hcs: "")
        let changes = IRDiffer().diff(old: old, new: new)
        XCTAssertTrue(changes.contains(.nodeAdded(path: "App > Database#replica")))
        XCTAssertTrue(changes.contains(.nodeRemoved(path: "App > Database#primary")))
    }

    func testRejectsV1Documents() throws {
        let commands = try Parser(source: "App\n").parse()
        let resolved = Resolver(sheet: CascadeSheet(rules: [])).resolve(commands)
        let v1 = Emitter().emit(resolved, as: .json)
        XCTAssertThrowsError(try IRDocument(json: JSONParser.parse(v1))) { error in
            XCTAssertTrue("\(error)".contains("hypercode.ir/v2"))
        }
    }

    // MARK: - JSON parser

    func testParserRoundTripsEmitterOutput() throws {
        let doc = try document(hc: hc, hcs: hcs, context: ["env": "test"])
        XCTAssertEqual(doc.context, ["env": "test"])
        XCTAssertEqual(doc.nodes.count, 1)
        XCTAssertEqual(doc.nodes[0].children.map(\.type), ["Service", "Cache"])
    }

    func testParserKeepsNumberLexemes() throws {
        guard case let .object(fields) = try JSONParser.parse(
            #"{"big": 9007199254740993, "neg": -1.5e3}"#) else {
            return XCTFail("expected object")
        }
        XCTAssertEqual(fields["big"], .number("9007199254740993"))
        XCTAssertEqual(fields["neg"], .number("-1.5e3"))
    }

    func testParserHandlesEscapesAndNesting() throws {
        let parsed = try JSONParser.parse(
            #"{"s": "a\"b\\c\nd A 😀", "a": [1, true, null, {"k": []}]}"#)
        guard case let .object(fields) = parsed else { return XCTFail() }
        XCTAssertEqual(fields["s"], .string("a\"b\\c\nd A 😀"))
        guard case let .array(items)? = fields["a"] else { return XCTFail() }
        XCTAssertEqual(items[0], .number("1"))
        XCTAssertEqual(items[1], .bool(true))
        XCTAssertEqual(items[2], .null)
    }

    func testParserRejectsMalformedInput() {
        for bad in ["{", "[1,", "\"unterminated", "{\"k\" 1}", "12 34", ""] {
            XCTAssertThrowsError(try JSONParser.parse(bad), "should reject: \(bad)")
        }
    }

    func testParserEnforcesRFC8259Numbers() {
        // diff reads arbitrary files from disk — the number grammar is strict.
        for bad in ["1.", "1e", ".5", "-.5", "01", "-01", "1.2e+", "-", "+1", "0x1"] {
            XCTAssertThrowsError(try JSONParser.parse(bad), "should reject: \(bad)")
        }
        for good in ["0", "-0", "0.5", "-0.5", "10", "1e10", "1E+10", "-1.5e-3"] {
            XCTAssertEqual(try? JSONParser.parse(good), .number(good), "should accept: \(good)")
        }
    }

    // MARK: - Rendering

    func testTextRendering() throws {
        let old = try document(hc: hc, hcs: hcs)
        let new = try document(hc: hc, hcs: hcs.replacingOccurrences(of: "port: 5000", with: "port: 9090"))
        let text = IRDiffer.renderText(IRDiffer().diff(old: old, new: new))
        XCTAssertTrue(text.contains("~ App > Service > Listen"))
        XCTAssertTrue(text.contains("port: 5000 → 9090"))
        XCTAssertTrue(text.contains("1 affected node(s)"))
        XCTAssertEqual(IRDiffer.renderText([]), "documents identical\n")
    }

    func testJSONRenderingIsValidAndVersioned() throws {
        let old = try document(hc: hc, hcs: hcs)
        let new = try document(hc: hc, hcs: hcs.replacingOccurrences(of: "port: 5000", with: "port: 9090"))
        let json = IRDiffer.renderJSON(IRDiffer().diff(old: old, new: new))
        guard case let .object(fields) = try JSONParser.parse(json) else {
            return XCTFail("diff JSON must parse")
        }
        XCTAssertEqual(fields["version"], .string("hypercode.diff/v1"))
        guard case let .array(changes)? = fields["changes"] else { return XCTFail() }
        XCTAssertEqual(changes.count, 1)
    }
}
