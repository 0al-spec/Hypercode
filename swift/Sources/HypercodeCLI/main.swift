import Foundation
import Hypercode

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    FileHandle.standardError.write(Data("usage: hypercode <file.hc>\n".utf8))
    exit(64) // EX_USAGE
}

let path = arguments[1]
do {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    guard let source = String(data: data, encoding: .utf8) else {
        FileHandle.standardError.write(Data("error: \(path) is not valid UTF-8\n".utf8))
        exit(1)
    }
    let ast = try Parser(source: source).parse()
    print(Command.tree(ast), terminator: "")
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}
