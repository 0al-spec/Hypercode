import XCTest
@testable import Hypercode

/// HC-116 — `@import` for `.hcs` cascade sheets.
final class ImportTests: XCTestCase {
    /// Dictionary-backed loader: targets are looked up verbatim, so the
    /// target string *is* the canonical identity.
    private func loader(_ sheets: [String: String]) -> ImportHandling {
        .loader { target, _ in
            guard let source = sheets[target] else {
                throw HCSError(message: "no such sheet '\(target)'", line: 1)
            }
            return (target, source)
        }
    }

    private func resolve(
        hc: String, entry: String, file: String = "entry.hcs",
        sheets: [String: String], context: ResolutionContext = [:]
    ) throws -> [ResolvedNode] {
        let commands = try Parser(source: hc).parse()
        let sheet = try CascadeSheetReader().read(entry, file: file, imports: loader(sheets))
        return Resolver(sheet: sheet, context: context).resolve(commands)
    }

    // MARK: - Cascade semantics

    func testImporterOverridesImportedOnEqualSpecificity() throws {
        // Imports expand at the directive position, so the importer's own
        // rules come later in source order and win specificity ties.
        let resolved = try resolve(
            hc: "Service\n",
            entry: "@import \"base.hcs\"\n\nService:\n  port: 9090\n",
            sheets: ["base.hcs": "Service:\n  port: 5000\n  timeout: 30\n"]
        )
        XCTAssertEqual(resolved[0].properties["port"]?.value.rawString, "9090")
        XCTAssertEqual(resolved[0].properties["timeout"]?.value.rawString, "30",
                       "non-overridden imported values must survive")
    }

    func testProvenanceKeepsDefiningFile() throws {
        let resolved = try resolve(
            hc: "Service\n",
            entry: "@import \"base.hcs\"\n\nService:\n  port: 9090\n",
            sheets: ["base.hcs": "Service:\n  port: 5000\n  timeout: 30\n"]
        )
        XCTAssertEqual(resolved[0].properties["timeout"]?.winner.file, "base.hcs")
        XCTAssertEqual(resolved[0].properties["port"]?.winner.file, "entry.hcs")
    }

    func testNestedImportsExpandDepthFirst() throws {
        let resolved = try resolve(
            hc: "Service\n",
            entry: "@import \"mid.hcs\"\nService:\n  a: entry\n",
            sheets: [
                "mid.hcs": "@import \"deep.hcs\"\nService:\n  a: mid\n  b: mid\n",
                "deep.hcs": "Service:\n  a: deep\n  b: deep\n  c: deep\n",
            ]
        )
        // deep < mid < entry in source order; later wins equal specificity.
        XCTAssertEqual(resolved[0].properties["a"]?.value.rawString, "entry")
        XCTAssertEqual(resolved[0].properties["b"]?.value.rawString, "mid")
        XCTAssertEqual(resolved[0].properties["c"]?.value.rawString, "deep")
    }

    func testDiamondImportsLoadOnce() throws {
        let sheet = try CascadeSheetReader().read(
            "@import \"left.hcs\"\n@import \"right.hcs\"\n",
            file: "entry.hcs",
            imports: loader([
                "left.hcs": "@import \"shared.hcs\"\nService:\n  l: 1\n",
                "right.hcs": "@import \"shared.hcs\"\nService:\n  r: 1\n",
                "shared.hcs": "Service:\n  s: 1\n",
            ])
        )
        let sharedRules = sheet.rules.filter { $0.file == "shared.hcs" }
        XCTAssertEqual(sharedRules.count, 1, "diamond import must expand once")
        XCTAssertEqual(sheet.rules.count, 3)
    }

    func testContractsAccumulateAcrossImports() throws {
        // A contract declared in the imported baseline still gates values
        // set by the importer (HC2104).
        let hc = "Service\n"
        let entry = "@import \"base.hcs\"\nService:\n  port: 99999\n"
        let sheets = ["base.hcs": "@contract:\n  Service:\n    port: int >= 1 <= 65535\n"]
        let commands = try Parser(source: hc).parse()
        let sheet = try CascadeSheetReader().read(entry, file: "entry.hcs", imports: loader(sheets))
        let resolved = Resolver(sheet: sheet).resolve(commands)
        let diags = ContractValueValidator().validate(
            resolved: resolved, commands: commands, contracts: sheet.contracts
        )
        XCTAssertEqual(diags.count, 1)
        XCTAssertEqual(diags.first?.code, "HC2104")
        XCTAssertTrue(diags.first?.message.contains("port") ?? false)
    }

    // MARK: - Errors

    func testDirectCycleFails() {
        XCTAssertThrowsError(try CascadeSheetReader().read(
            "@import \"a.hcs\"\n", file: "a.hcs",
            imports: loader(["a.hcs": "@import \"a.hcs\"\n"])
        )) { error in
            XCTAssertTrue("\(error)".contains("import cycle"), "\(error)")
        }
    }

    func testIndirectCycleFails() {
        XCTAssertThrowsError(try CascadeSheetReader().read(
            "@import \"b.hcs\"\n", file: "a.hcs",
            imports: loader([
                "a.hcs": "@import \"b.hcs\"\n",
                "b.hcs": "@import \"c.hcs\"\n",
                "c.hcs": "@import \"a.hcs\"\n",
            ])
        )) { error in
            XCTAssertTrue("\(error)".contains("import cycle"), "\(error)")
        }
    }

    func testImportAfterRuleFails() {
        XCTAssertThrowsError(try CascadeSheetReader().read(
            "Service:\n  a: 1\n@import \"base.hcs\"\n",
            imports: loader(["base.hcs": ""])
        )) { error in
            XCTAssertTrue("\(error)".contains("must precede"), "\(error)")
        }
    }

    func testImportWithoutLoaderFails() {
        XCTAssertThrowsError(try CascadeSheetReader().read("@import \"base.hcs\"\n")) { error in
            XCTAssertTrue("\(error)".contains("no import loader"), "\(error)")
        }
    }

    func testSyntaxOnlyToleratesImports() throws {
        let sheet = try CascadeSheetReader().read(
            "@import \"base.hcs\"\nService:\n  a: 1\n", imports: .syntaxOnly
        )
        XCTAssertEqual(sheet.rules.count, 1, "own rules parse; imports are skipped")
    }

    func testUnreadableImportFails() {
        XCTAssertThrowsError(try CascadeSheetReader().read(
            "@import \"missing.hcs\"\n", imports: loader([:])
        )) { error in
            XCTAssertTrue("\(error)".contains("missing.hcs"), "\(error)")
        }
    }

    func testMalformedDirectives() {
        for bad in [
            "@import base.hcs\n",          // unquoted
            "@import \"\"\n",              // empty path
            "@import\n",                   // no target
            "@import \"a.hcs\"\n  x: 1\n", // nested block
        ] {
            XCTAssertThrowsError(
                try CascadeSheetReader().read(bad, imports: loader(["a.hcs": ""])),
                "should reject: \(bad.debugDescription)"
            )
        }
    }

    func testImportPrefixedGuardIsNotAnImport() throws {
        // `@important[x]:` is a context guard, not a typo'd directive.
        let sheet = try CascadeSheetReader().read(
            "@important[on]:\n  Service:\n    a: 1\n"
        )
        XCTAssertEqual(sheet.rules.count, 1)
        XCTAssertEqual(sheet.rules[0].condition?.dimension, "important")
    }

    func testDanglingSelectorDiagnosticNamesTheDefiningFile() throws {
        // HC3002 for a dead selector in an imported baseline must point at
        // the baseline, not at the entry sheet that imported it.
        let commands = try Parser(source: "Service\n").parse()
        let sheet = try CascadeSheetReader().read(
            "@import \"base.hcs\"\nService:\n  a: 1\n", file: "entry.hcs",
            imports: loader(["base.hcs": "LegacyQueue:\n  x: 1\n"])
        )
        let diags = Validator().validate(sheet, against: commands)
        XCTAssertEqual(diags.count, 1)
        XCTAssertEqual(diags.first?.code, "HC3002")
        XCTAssertEqual(diags.first?.file, "base.hcs")
    }

    func testErrorInImportedSheetNamesTheFile() {
        XCTAssertThrowsError(try CascadeSheetReader().read(
            "@import \"broken.hcs\"\n", file: "entry.hcs",
            imports: loader(["broken.hcs": "Service\n  a: 1\n"]) // missing ':'
        )) { error in
            XCTAssertTrue("\(error)".contains("broken.hcs"), "\(error)")
        }
    }
}
