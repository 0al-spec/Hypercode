/// A parsed JSON value. Numbers keep their source lexeme so comparisons are
/// exact — `9007199254740993` never collapses into `9007199254740992` the way
/// it would through `Double`.
public enum JSONValue: Equatable, Sendable {
    case string(String)
    case number(String) // raw lexeme
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([String: JSONValue])

    /// Scalar display text for diff output (objects/arrays render as markers).
    public var scalarText: String {
        switch self {
        case .string(let s): return s
        case .number(let n): return n
        case .bool(let b): return b ? "true" : "false"
        case .null: return "null"
        case .array: return "[…]"
        case .object: return "{…}"
        }
    }
}

/// An error raised while parsing JSON text.
public struct JSONError: Error, Equatable, CustomStringConvertible, Sendable {
    public let message: String

    public var description: String { "json error: \(message)" }
}

/// A minimal, hand-rolled JSON parser — Foundation-free, like the rest of the
/// core. Primary input is our own emitter's canonical output, but it accepts
/// any valid JSON document.
public enum JSONParser {
    public static func parse(_ text: String) throws -> JSONValue {
        var scanner = Scanner(Array(text))
        let value = try scanner.parseValue()
        scanner.skipWhitespace()
        guard scanner.isAtEnd else {
            throw JSONError(message: "trailing characters after JSON value")
        }
        return value
    }

    private struct Scanner {
        let chars: [Character]
        var index = 0

        init(_ chars: [Character]) { self.chars = chars }

        var isAtEnd: Bool { index >= chars.count }

        mutating func skipWhitespace() {
            while index < chars.count, " \t\n\r".contains(chars[index]) { index += 1 }
        }

        mutating func parseValue() throws -> JSONValue {
            skipWhitespace()
            guard index < chars.count else { throw JSONError(message: "unexpected end of input") }
            switch chars[index] {
            case "{": return try parseObject()
            case "[": return try parseArray()
            case "\"": return .string(try parseString())
            case "t": try expect("true"); return .bool(true)
            case "f": try expect("false"); return .bool(false)
            case "n": try expect("null"); return .null
            default: return .number(try parseNumberLexeme())
            }
        }

        mutating func parseObject() throws -> JSONValue {
            index += 1 // {
            var pairs: [String: JSONValue] = [:]
            skipWhitespace()
            if index < chars.count, chars[index] == "}" { index += 1; return .object(pairs) }
            while true {
                skipWhitespace()
                guard index < chars.count, chars[index] == "\"" else {
                    throw JSONError(message: "expected object key")
                }
                let key = try parseString()
                skipWhitespace()
                guard index < chars.count, chars[index] == ":" else {
                    throw JSONError(message: "expected ':' after object key '\(key)'")
                }
                index += 1
                pairs[key] = try parseValue()
                skipWhitespace()
                guard index < chars.count else { throw JSONError(message: "unterminated object") }
                if chars[index] == "," { index += 1; continue }
                if chars[index] == "}" { index += 1; return .object(pairs) }
                throw JSONError(message: "expected ',' or '}' in object")
            }
        }

        mutating func parseArray() throws -> JSONValue {
            index += 1 // [
            var items: [JSONValue] = []
            skipWhitespace()
            if index < chars.count, chars[index] == "]" { index += 1; return .array(items) }
            while true {
                items.append(try parseValue())
                skipWhitespace()
                guard index < chars.count else { throw JSONError(message: "unterminated array") }
                if chars[index] == "," { index += 1; continue }
                if chars[index] == "]" { index += 1; return .array(items) }
                throw JSONError(message: "expected ',' or ']' in array")
            }
        }

        mutating func parseString() throws -> String {
            index += 1 // opening quote
            var out = ""
            while index < chars.count {
                let c = chars[index]
                if c == "\"" { index += 1; return out }
                if c == "\\" {
                    index += 1
                    guard index < chars.count else { break }
                    switch chars[index] {
                    case "\"": out.append("\"")
                    case "\\": out.append("\\")
                    case "/": out.append("/")
                    case "b": out.append("\u{08}")
                    case "f": out.append("\u{0C}")
                    case "n": out.append("\n")
                    case "r": out.append("\r")
                    case "t": out.append("\t")
                    case "u": out.append(try parseUnicodeEscape())
                    default: throw JSONError(message: "invalid escape '\\\(chars[index])'")
                    }
                    index += 1
                } else {
                    out.append(c)
                    index += 1
                }
            }
            throw JSONError(message: "unterminated string")
        }

        /// Parses the 4 hex digits after `\u`, combining surrogate pairs.
        mutating func parseUnicodeEscape() throws -> Character {
            func hex4() throws -> UInt32 {
                guard index + 4 < chars.count else {
                    throw JSONError(message: "truncated \\u escape")
                }
                var value: UInt32 = 0
                for offset in 1...4 {
                    guard let digit = chars[index + offset].hexDigitValue else {
                        throw JSONError(message: "invalid \\u escape")
                    }
                    value = value << 4 | UInt32(digit)
                }
                index += 4
                return value
            }
            let unit = try hex4()
            if (0xD800...0xDBFF).contains(unit) {
                guard index + 2 < chars.count,
                      chars[index + 1] == "\\", chars[index + 2] == "u" else {
                    throw JSONError(message: "unpaired surrogate in \\u escape")
                }
                index += 2
                let low = try hex4()
                guard (0xDC00...0xDFFF).contains(low) else {
                    throw JSONError(message: "invalid low surrogate in \\u escape")
                }
                let scalar = 0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00)
                return Character(Unicode.Scalar(scalar)!)
            }
            guard let scalar = Unicode.Scalar(unit) else {
                throw JSONError(message: "invalid \\u escape")
            }
            return Character(scalar)
        }

        mutating func parseNumberLexeme() throws -> String {
            let start = index
            if index < chars.count, chars[index] == "-" { index += 1 }
            while index < chars.count, chars[index].isNumber { index += 1 }
            if index < chars.count, chars[index] == "." {
                index += 1
                while index < chars.count, chars[index].isNumber { index += 1 }
            }
            if index < chars.count, chars[index] == "e" || chars[index] == "E" {
                index += 1
                if index < chars.count, chars[index] == "+" || chars[index] == "-" { index += 1 }
                while index < chars.count, chars[index].isNumber { index += 1 }
            }
            guard index > start, String(chars[start..<index]) != "-" else {
                throw JSONError(message: "invalid number")
            }
            return String(chars[start..<index])
        }

        mutating func expect(_ literal: String) throws {
            for expected in literal {
                guard index < chars.count, chars[index] == expected else {
                    throw JSONError(message: "invalid literal (expected '\(literal)')")
                }
                index += 1
            }
        }
    }
}
