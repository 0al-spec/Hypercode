/// A single raw source line of a `.hc` document, tagged with its 1-based number.
///
/// The domain type the lexical and syntactic line specifications operate on.
public struct RawLine: Equatable, Sendable {
    public let number: Int
    public let text: String

    public init(number: Int, text: String) {
        self.number = number
        self.text = text
    }

    /// Width of the leading run of spaces/tabs.
    public var indentation: Int {
        text.prefix { $0 == " " || $0 == "\t" }.count
    }

    /// The line with leading and trailing spaces/tabs removed.
    public var trimmed: Substring {
        var slice = text[...]
        while let first = slice.first, first == " " || first == "\t" {
            slice = slice.dropFirst()
        }
        while let last = slice.last, last == " " || last == "\t" {
            slice = slice.dropLast()
        }
        return slice
    }

    /// True when the line is empty or whitespace-only.
    public var isBlank: Bool { trimmed.isEmpty }
}

/// The lexical classification of a `.hc` line.
public enum LineKind: Equatable, Sendable {
    case blank
    case command
}
