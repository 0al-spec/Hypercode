import XCTest
@testable import Hypercode

/// End-to-end cascade resolution, mirroring the web-service example in RFC §5.
final class CascadeResolverTests: XCTestCase {
    private let hc = [
        "Service",
        "  Logger.console",
        "  Database#main-db",
        "    Connect",
        "  APIServer",
        "    Listen",
    ].joined(separator: "\n") + "\n"

    private let hcs = [
        "Logger:",
        "  level: \"debug\"",
        ".console:",
        "  format: \"text\"",
        "Database:",
        "  driver: \"sqlite\"",
        "  file: \"dev.sqlite3\"",
        "APIServer > Listen:",
        "  host: \"127.0.0.1\"",
        "  port: 5000",
        "@env[production]:",
        "  Logger:",
        "    level: \"info\"",
        "  .console:",
        "    format: \"json\"",
        "  '#main-db':",
        "    driver: \"postgres\"",
        "    pool_size: 50",
        "  APIServer > Listen:",
        "    host: \"0.0.0.0\"",
        "    port: 8080",
    ].joined(separator: "\n") + "\n"

    private func resolve(env: String? = nil) throws -> [ResolvedNode] {
        let forest = try Parser(source: hc).parse()
        let sheet = try CascadeSheetReader().read(hcs)
        let context: ResolutionContext = env.map { ["env": $0] } ?? [:]
        return Resolver(sheet: sheet, context: context).resolve(forest)
    }

    private func find(_ type: String, in forest: [ResolvedNode]) -> ResolvedNode? {
        for node in forest {
            if node.type == type { return node }
            if let found = find(type, in: node.children) { return found }
        }
        return nil
    }

    func testDevelopmentResolution() throws {
        let tree = try resolve()

        let logger = try XCTUnwrap(find("Logger", in: tree))
        XCTAssertEqual(logger.properties["level"]?.value, .string("debug"))   // Logger type
        XCTAssertEqual(logger.properties["format"]?.value, .string("text"))   // .console class

        let database = try XCTUnwrap(find("Database", in: tree))
        XCTAssertEqual(database.properties["driver"]?.value, .string("sqlite"))
        XCTAssertEqual(database.properties["file"]?.value, .string("dev.sqlite3"))
        XCTAssertNil(database.properties["pool_size"])               // production-only

        let listen = try XCTUnwrap(find("Listen", in: tree))
        XCTAssertEqual(listen.properties["host"]?.value, .string("127.0.0.1"))
        XCTAssertEqual(listen.properties["port"]?.value, .int(5000))
    }

    func testProductionResolution() throws {
        let tree = try resolve(env: "production")

        let logger = try XCTUnwrap(find("Logger", in: tree))
        XCTAssertEqual(logger.properties["level"]?.value, .string("info"))    // later source order wins
        XCTAssertEqual(logger.properties["format"]?.value, .string("json"))

        let database = try XCTUnwrap(find("Database", in: tree))
        XCTAssertEqual(database.properties["driver"]?.value, .string("postgres")) // #id beats type
        XCTAssertEqual(database.properties["pool_size"]?.value, .int(50))
        XCTAssertEqual(database.properties["file"]?.value, .string("dev.sqlite3")) // not overridden

        let listen = try XCTUnwrap(find("Listen", in: tree))
        XCTAssertEqual(listen.properties["host"]?.value, .string("0.0.0.0"))
        XCTAssertEqual(listen.properties["port"]?.value, .int(8080))
    }

    func testProvenanceTracksWinningSelector() throws {
        let dev = try XCTUnwrap(find("Database", in: try resolve()))
        XCTAssertEqual(dev.properties["driver"]?.provenance.selector, .type("Database"))

        let prod = try XCTUnwrap(find("Database", in: try resolve(env: "production")))
        XCTAssertEqual(prod.properties["driver"]?.provenance.selector, .id("main-db"))
    }

    func testLosersAreRetained() throws {
        // In production, driver: "postgres" (#main-db, specificity (1,0,0)) beats
        // driver: "sqlite" (Database, specificity (0,0,1)). The loser must be retained.
        let prod = try XCTUnwrap(find("Database", in: try resolve(env: "production")))
        let driverResolved = try XCTUnwrap(prod.properties["driver"])
        XCTAssertEqual(driverResolved.winner.value, .string("postgres"))
        XCTAssertEqual(driverResolved.winner.selector, .id("main-db"))
        XCTAssertEqual(driverResolved.losers.count, 1)
        XCTAssertEqual(driverResolved.losers[0].value, .string("sqlite"))
        XCTAssertEqual(driverResolved.losers[0].selector, .type("Database"))
    }
}
