import Foundation
import Hypercode

let usage = """
usage:
  hypercode parse <file.hc>
  hypercode resolve <file.hc> --hcs <file.hcs> [--ctx key=value]...
"""

func fail(_ message: String, code: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

func readSource(_ path: String) -> String {
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
    let sheet = try CascadeSheetReader().read(readSource(hcsPath))
    let resolved = Resolver(sheet: sheet, context: context).resolve(forest)
    print(ResolvedNode.tree(resolved), terminator: "")
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard let command = arguments.first else {
    fail(usage, code: 64)
}

do {
    switch command {
    case "resolve":
        try runResolve(Array(arguments.dropFirst()))
    case "parse":
        guard arguments.count >= 2 else { fail(usage, code: 64) }
        try runParse(arguments[1])
    default:
        // Backwards-compatible shorthand: `hypercode <file.hc>`.
        try runParse(command)
    }
} catch {
    fail("\(error)")
}
