/// The kind of document being diagnosed.
public enum DocumentKind: Equatable, Sendable {
    case hypercode      // .hc
    case cascadeSheet   // .hcs

    /// Infer the kind from a path or URI by extension (defaults to `.hypercode`).
    public init(path: String) {
        self = path.lowercased().hasSuffix(".hcs") ? .cascadeSheet : .hypercode
    }
}

/// Computes diagnostics for a single document's text — the shared core of the
/// LSP server's live diagnostics and of `hypercode validate`.
public func diagnostics(for kind: DocumentKind, text: String, file: String? = nil) -> [Diagnostic] {
    do {
        switch kind {
        case .cascadeSheet:
            _ = try CascadeSheetReader().read(text)
            return []
        case .hypercode:
            let forest = try Parser(source: text).parse()
            return Validator().validate(forest)
        }
    } catch let error as DiagnosticConvertible {
        return [error.diagnostic(file: file)]
    } catch {
        // Surface, don't silently report the document as clean.
        return [Diagnostic(severity: .error, code: "HC9000",
                           message: "internal error: \(error)", file: file)]
    }
}
