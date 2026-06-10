import XCTest
@testable import Hypercode

/// Verifies the `Explainer` cascade trace using the RFC §5 service example.
final class ExplainTests: XCTestCase {
    private let hc = """
        Service
          Logger.console
          Database#main-db
            Connect
          APIServer
            Listen
        """

    private let hcs = """
        Logger:
          level: "debug"
        .console:
          format: "text"
        Database:
          driver: "sqlite"
          file: "dev.sqlite3"
        APIServer > Listen:
          host: "127.0.0.1"
          port: 5000
        @env[production]:
          Logger:
            level: "info"
          .console:
            format: "json"
          '#main-db':
            driver: "postgres"
            pool_size: 50
          APIServer > Listen:
            host: "0.0.0.0"
            port: 8080
        """

    private func explainer(env: String? = nil) throws -> Explainer {
        let commands = try Parser(source: hc).parse()
        let sheet = try CascadeSheetReader().read(hcs)
        let context: ResolutionContext = env.map { ["env": $0] } ?? [:]
        let resolved = Resolver(sheet: sheet, context: context).resolve(commands)
        return Explainer(commands: commands, resolved: resolved)
    }

    func testSinglePropertyExplainDev() throws {
        let ex = try explainer()
        let traces = ex.explain(
            selector: try CascadeSheetReader().parseSelector(fromString: "Database"),
            property: "driver"
        )
        XCTAssertEqual(traces.count, 1)
        let trace = traces[0]
        XCTAssertEqual(trace.nodePath, "Service > Database#main-db")
        XCTAssertEqual(trace.properties.count, 1)
        let prop = trace.properties[0]
        XCTAssertEqual(prop.key, "driver")
        XCTAssertEqual(prop.winner.value, .string("sqlite"))
        XCTAssertEqual(prop.winner.selector, .type("Database"))
        XCTAssertTrue(prop.losers.isEmpty)
    }

    func testSinglePropertyExplainProduction() throws {
        let ex = try explainer(env: "production")
        let traces = ex.explain(
            selector: try CascadeSheetReader().parseSelector(fromString: "Database"),
            property: "driver"
        )
        XCTAssertEqual(traces.count, 1)
        let prop = traces[0].properties[0]
        // #main-db beats Database by specificity
        XCTAssertEqual(prop.winner.value, .string("postgres"))
        XCTAssertEqual(prop.winner.selector, .id("main-db"))
        // The losing Database rule should be retained
        XCTAssertEqual(prop.losers.count, 1)
        XCTAssertEqual(prop.losers[0].value, .string("sqlite"))
        XCTAssertEqual(prop.losers[0].selector, .type("Database"))
    }

    func testChildSelectorExplain() throws {
        let ex = try explainer(env: "production")
        let traces = ex.explain(
            selector: try CascadeSheetReader().parseSelector(fromString: "APIServer > Listen"),
            property: "port"
        )
        XCTAssertEqual(traces.count, 1)
        let prop = traces[0].properties[0]
        XCTAssertEqual(prop.winner.value, .int(8080))
    }

    func testNoMatchReturnsEmpty() throws {
        let ex = try explainer()
        let traces = ex.explain(
            selector: try CascadeSheetReader().parseSelector(fromString: "NonExistent"),
            property: nil
        )
        XCTAssertTrue(traces.isEmpty)
    }

    func testAllPropertiesWhenFilterNil() throws {
        let ex = try explainer()
        let traces = ex.explain(
            selector: try CascadeSheetReader().parseSelector(fromString: "Database"),
            property: nil
        )
        XCTAssertEqual(traces.count, 1)
        // Database has driver and file in dev context
        let keys = Set(traces[0].properties.map(\.key))
        XCTAssertEqual(keys, ["driver", "file"])
    }

    func testTextRenderingContainsExpectedLines() throws {
        let ex = try explainer(env: "production")
        let traces = ex.explain(
            selector: try CascadeSheetReader().parseSelector(fromString: "Database"),
            property: "driver"
        )
        let text = traces[0].renderText()
        XCTAssertTrue(text.contains("driver"))
        XCTAssertTrue(text.contains("WINNER"))
        XCTAssertTrue(text.contains("postgres"))
        XCTAssertTrue(text.contains("losing"))
        XCTAssertTrue(text.contains("sqlite"))
    }
}
