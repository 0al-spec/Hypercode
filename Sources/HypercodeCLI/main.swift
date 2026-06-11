import Foundation
import Hypercode

let usage = """
usage:
  hypercode parse    <file.hc>
  hypercode validate <file.hc> [--hcs <file.hcs>] [--ctx key=value]...
  hypercode resolve  <file.hc> --hcs <file.hcs> [--ctx key=value]...
  hypercode emit     <file.hc> [--hcs <file.hcs>] [--ctx key=value]... [--format json|yaml] [--ir-version 1|2]
  hypercode explain  <file.hc> --hcs <file.hcs> [--ctx key=value]... <selector> [property]
  hypercode lsp                                                    # language server (LSP over stdio)

global: [--diagnostics text|json]
"""

var diagnosticsFormat: DiagnosticFormat = .text
var currentInputFile: String?

func fail(_ message: String, code: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

func readSource(_ path: String) -> String {
    currentInputFile = path
    guard
        let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
        let text = String(data: data, encoding: .utf8)
    else {
        fail("error: cannot read \(path)")
    }
    return text
}

func runParse(_ path: String) throws {
    let forest = try Parser(source: readSource(path)).parse()
    print(Command.tree(forest), terminator: "")
}

func runResolve(_ args: [String]) throws {
    var hcPath: String?
    var hcsPath: String?
    var context: ResolutionContext = [:]

    var index = 0
    while index < args.count {
        switch args[index] {
        case "--hcs":
            index += 1
            guard index < args.count else { fail("error: --hcs needs a path") }
            hcsPath = args[index]
        case "--ctx":
            index += 1
            guard index < args.count else { fail("error: --ctx needs key=value") }
            let pair = args[index]
            guard let equals = pair.firstIndex(of: "=") else {
                fail("error: --ctx expects key=value, got '\(pair)'")
            }
            context[String(pair[..<equals])] = String(pair[pair.index(after: equals)...])
        default:
            if hcPath == nil { hcPath = args[index] } else {
                fail("error: unexpected argument '\(args[index])'")
            }
        }
        index += 1
    }

    guard let hcPath else { fail("error: resolve needs a .hc file\n\n\(usage)", code: 64) }
    guard let hcsPath else { fail("error: resolve needs --hcs <file.hcs>\n\n\(usage)", code: 64) }

    let forest = try Parser(source: readSource(hcPath)).parse()
    let sheet = try CascadeSheetReader().read(readSource(hcsPath), file: hcsPath)
    let resolved = Resolver(sheet: sheet, context: context).resolve(forest)
    print(ResolvedNode.tree(resolved), terminator: "")
}

func runValidate(_ args: [String]) throws {
    var hcPath: String?
    var hcsPath: String?
    var context: ResolutionContext = [:]

    var index = 0
    while index < args.count {
        switch args[index] {
        case "--hcs":
            index += 1
            guard index < args.count else { fail("error: --hcs needs a path") }
            hcsPath = args[index]
        case "--ctx":
            index += 1
            guard index < args.count else { fail("error: --ctx needs key=value") }
            let pair = args[index]
            guard let equals = pair.firstIndex(of: "=") else {
                fail("error: --ctx expects key=value, got '\(pair)'")
            }
            context[String(pair[..<equals])] = String(pair[pair.index(after: equals)...])
        default:
            if hcPath == nil { hcPath = args[index] } else {
                fail("error: unexpected argument '\(args[index])'")
            }
        }
        index += 1
    }

    guard let hcPath else { fail("error: validate needs a .hc file\n\n\(usage)", code: 64) }

    func tagged(_ diagnostics: [Diagnostic], file: String) -> [Diagnostic] {
        diagnostics.map {
            Diagnostic(severity: $0.severity, code: $0.code, message: $0.message,
                       file: $0.file ?? file, range: $0.range)
        }
    }

    let forest = try Parser(source: readSource(hcPath)).parse()
    let validator = Validator()
    // .hc diagnostics point at the .hc file; .hcs diagnostics at the .hcs file.
    var located = tagged(validator.validate(forest), file: hcPath)
    if let hcsPath {
        let sheet = try CascadeSheetReader().read(readSource(hcsPath), file: hcsPath)
        located += tagged(validator.validate(sheet, against: forest), file: hcsPath)
        // Value-level contract checks run on the resolved graph (HC2104) —
        // resolution is context-dependent, hence validate accepts --ctx.
        let resolved = Resolver(sheet: sheet, context: context).resolve(forest)
        located += tagged(
            ContractValueValidator().validate(
                resolved: resolved, commands: forest, contracts: sheet.contracts
            ),
            file: hcsPath
        )
    }
    switch diagnosticsFormat {
    case .json:
        print(DiagnosticsRenderer.render(located, as: .json))
    case .text:
        print(located.isEmpty ? "ok: no issues found" : DiagnosticsRenderer.render(located, as: .text))
    }
    if located.contains(where: { $0.severity == .error }) {
        exit(1)
    }
}

func runEmit(_ args: [String]) throws {
    var hcPath: String?
    var hcsPath: String?
    var context: ResolutionContext = [:]
    var format: EmitFormat = .json
    var irVersion: EmitVersion = .v2

    var index = 0
    while index < args.count {
        switch args[index] {
        case "--hcs":
            index += 1
            guard index < args.count else { fail("error: --hcs needs a path") }
            hcsPath = args[index]
        case "--ctx":
            index += 1
            guard index < args.count else { fail("error: --ctx needs key=value") }
            let pair = args[index]
            guard let equals = pair.firstIndex(of: "=") else {
                fail("error: --ctx expects key=value, got '\(pair)'")
            }
            context[String(pair[..<equals])] = String(pair[pair.index(after: equals)...])
        case "--format":
            index += 1
            guard index < args.count, let parsed = EmitFormat(rawValue: args[index]) else {
                fail("error: --format expects json|yaml")
            }
            format = parsed
        case "--ir-version":
            index += 1
            guard index < args.count, let parsed = EmitVersion(rawValue: args[index]) else {
                fail("error: --ir-version expects 1|2")
            }
            irVersion = parsed
        default:
            if hcPath == nil { hcPath = args[index] } else {
                fail("error: unexpected argument '\(args[index])'")
            }
        }
        index += 1
    }

    guard let hcPath else { fail("error: emit needs a .hc file\n\n\(usage)", code: 64) }

    let commands = try Parser(source: readSource(hcPath)).parse()
    let sheet = try hcsPath.map { p in try CascadeSheetReader().read(readSource(p), file: p) } ?? CascadeSheet(rules: [])
    let resolved = Resolver(sheet: sheet, context: context).resolve(commands)
    print(Emitter().emit(resolved, version: irVersion, context: context,
                         commands: commands, contracts: sheet.contracts, as: format), terminator: "")
}

func runExplain(_ args: [String]) throws {
    var hcPath: String?
    var hcsPath: String?
    var context: ResolutionContext = [:]
    var positional: [String] = []

    var index = 0
    while index < args.count {
        switch args[index] {
        case "--hcs":
            index += 1
            guard index < args.count else { fail("error: --hcs needs a path") }
            hcsPath = args[index]
        case "--ctx":
            index += 1
            guard index < args.count else { fail("error: --ctx needs key=value") }
            let pair = args[index]
            guard let equals = pair.firstIndex(of: "=") else {
                fail("error: --ctx expects key=value, got '\(pair)'")
            }
            context[String(pair[..<equals])] = String(pair[pair.index(after: equals)...])
        default:
            if hcPath == nil { hcPath = args[index] } else { positional.append(args[index]) }
        }
        index += 1
    }

    guard let hcPath else { fail("error: explain needs a .hc file\n\n\(usage)", code: 64) }
    guard let hcsPath else { fail("error: explain needs --hcs <file.hcs>\n\n\(usage)", code: 64) }
    guard !positional.isEmpty else { fail("error: explain needs a <selector>\n\n\(usage)", code: 64) }
    guard positional.count <= 2 else {
        fail("error: unexpected argument '\(positional[2])' — explain takes <selector> [property]\n\n\(usage)", code: 64)
    }

    let selectorText = positional[0]
    let propertyFilter: String? = positional.count == 2 ? positional[1] : nil

    let selectorParsed: Hypercode.Selector
    do {
        selectorParsed = try CascadeSheetReader().parseSelector(fromString: selectorText)
    } catch {
        fail("error: invalid selector '\(selectorText)': \(error)")
    }

    let commands = try Parser(source: readSource(hcPath)).parse()
    let sheet = try CascadeSheetReader().read(readSource(hcsPath), file: hcsPath)
    let resolved = Resolver(sheet: sheet, context: context).resolve(commands)
    let traces = Explainer(commands: commands, resolved: resolved).explain(
        selector: selectorParsed, property: propertyFilter
    )

    if traces.isEmpty {
        let msg = "no nodes matched selector '\(selectorText)'"
        FileHandle.standardError.write(Data((msg + "\n").utf8))
        exit(1)
    }

    let countStr = traces.count == 1 ? "1 node" : "\(traces.count) nodes"
    print("Matched \(countStr) for selector '\(selectorText)'\n")
    for trace in traces {
        print("Node: \(trace.nodePath)")
        if trace.properties.isEmpty {
            print("  (no resolved properties)")
        } else {
            print(trace.renderText(), terminator: "")
        }
        print("")
    }
}

// Pull the global `--diagnostics <format>` flag out of the argument list.
let arguments: [String] = {
    let raw = Array(CommandLine.arguments.dropFirst())
    var rest: [String] = []
    var index = 0
    while index < raw.count {
        if raw[index] == "--diagnostics" {
            index += 1
            guard index < raw.count, let format = DiagnosticFormat(rawValue: raw[index]) else {
                fail("error: --diagnostics expects text|json")
            }
            diagnosticsFormat = format
        } else {
            rest.append(raw[index])
        }
        index += 1
    }
    return rest
}()

guard let command = arguments.first else {
    fail(usage, code: 64)
}

do {
    switch command {
    case "--help", "-h":
        print(usage)
    case "resolve":
        try runResolve(Array(arguments.dropFirst()))
    case "validate":
        try runValidate(Array(arguments.dropFirst()))
    case "emit":
        try runEmit(Array(arguments.dropFirst()))
    case "explain":
        try runExplain(Array(arguments.dropFirst()))
    case "lsp":
        LSPServer().run()
    case "parse":
        guard arguments.count >= 2 else { fail(usage, code: 64) }
        try runParse(arguments[1])
    default:
        // Backwards-compatible shorthand: `hypercode <file.hc>`.
        try runParse(command)
    }
} catch let error as DiagnosticConvertible {
    let rendered = DiagnosticsRenderer.render([error.diagnostic(file: currentInputFile)], as: diagnosticsFormat)
    FileHandle.standardError.write(Data((rendered + "\n").utf8))
    exit(1)
} catch {
    fail("\(error)")
}
