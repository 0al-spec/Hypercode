import Foundation
import Hypercode

let usage = """
usage:
  hypercode parse    <file.hc>
  hypercode validate <file.hc> [--hcs <file.hcs>]
  hypercode resolve  <file.hc> --hcs <file.hcs> [--ctx key=value]...
  hypercode emit     <file.hc> [--hcs <file.hcs>] [--ctx key=value]... [--format json|yaml] [--ir-version 1|2]
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

/// Parses a `--ctx key=value` argument. The key must be a Hypercode
/// identifier — the same lexical class as `@dimension` names — so a typo
/// fails loudly here instead of silently matching nothing (and so arbitrary
/// text can never reach the emitted IR as an object key).
func parseContextAssignment(_ pair: String) -> (key: String, value: String) {
    guard let equals = pair.firstIndex(of: "=") else {
        fail("error: --ctx expects key=value, got '\(pair)'")
    }
    let key = String(pair[..<equals])
    guard IdentifierSpec().isSatisfiedBy(key) else {
        fail("error: --ctx key must be an identifier, got '\(key)'")
    }
    return (key, String(pair[pair.index(after: equals)...]))
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
            let (key, value) = parseContextAssignment(args[index])
            context[key] = value
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

    var index = 0
    while index < args.count {
        switch args[index] {
        case "--hcs":
            index += 1
            guard index < args.count else { fail("error: --hcs needs a path") }
            hcsPath = args[index]
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
            let (key, value) = parseContextAssignment(args[index])
            context[key] = value
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

    let forest = try Parser(source: readSource(hcPath)).parse()
    let sheet = try hcsPath.map { p in try CascadeSheetReader().read(readSource(p), file: p) } ?? CascadeSheet(rules: [])
    let resolved = Resolver(sheet: sheet, context: context).resolve(forest)
    print(Emitter().emit(resolved, version: irVersion, context: context, as: format), terminator: "")
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
