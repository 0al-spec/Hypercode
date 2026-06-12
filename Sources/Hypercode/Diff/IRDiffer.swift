/// One property-level difference inside a modified node.
public struct PropertyDiff: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case added(new: String, winner: String)
        case removed(old: String)
        case changed(old: String, new: String, oldWinner: String, newWinner: String)
    }

    public let key: String
    public let kind: Kind

    public init(key: String, kind: Kind) {
        self.key = key
        self.kind = kind
    }
}

/// One node-level change between two IR v2 documents.
public enum IRChange: Equatable, Sendable {
    case nodeAdded(path: String)
    case nodeRemoved(path: String)
    case nodeModified(path: String, properties: [PropertyDiff])
    /// Matched children changed relative order under this path. Reordering
    /// changes parent hashes (they are Merkle over children) without any
    /// value changing.
    case childrenReordered(path: String)
}

/// Computes the affected-node set between two `hypercode.ir/v2` documents —
/// the invalidation signal for incremental regeneration (HC-113).
///
/// Node hashes drive the traversal: a subtree whose hash is unchanged is
/// skipped entirely, so the cost is proportional to what changed, not to the
/// size of the tree. Nodes are matched across versions by their selector
/// identity (`type[.class][#id]`); duplicate siblings pair by content hash
/// first, then by source order — so a duplicate that merely moved is a
/// reorder, not two modifications. Provenance-only changes (a different rule
/// winning the same value) do not alter hashes and therefore do not appear
/// in the diff.
public struct IRDiffer {
    public init() {}

    public func diff(old: IRDocument, new: IRDocument) -> [IRChange] {
        guard old.documentHash != new.documentHash else { return [] }
        var changes: [IRChange] = []
        diffForest(old.nodes, new.nodes, parentPath: "", into: &changes)
        return changes
    }

    // MARK: - Tree walk

    private func diffForest(
        _ old: [IRNode], _ new: [IRNode],
        parentPath: String,
        into changes: inout [IRChange]
    ) {
        let pairedOldIndex = pairChildren(old, new)

        var matchedOldOrder: [Int] = []
        for (newIndex, node) in new.enumerated() {
            let path = join(parentPath, node.label)
            if let oldIndex = pairedOldIndex[newIndex] {
                matchedOldOrder.append(oldIndex)
                diffNode(old[oldIndex], node, path: path, into: &changes)
            } else {
                changes.append(.nodeAdded(path: path))
            }
        }
        let matched = Set(pairedOldIndex.compactMap { $0 })
        for oldIndex in old.indices where !matched.contains(oldIndex) {
            changes.append(.nodeRemoved(path: join(parentPath, old[oldIndex].label)))
        }
        if matchedOldOrder != matchedOldOrder.sorted() {
            changes.append(.childrenReordered(path: parentPath.isEmpty ? "(root)" : parentPath))
        }
    }

    /// For each new child, the index of the old child it pairs with (nil =
    /// added). Pairing is per selector-identity label; inside a label group
    /// equal hashes pair first, so a duplicate sibling that only moved keeps
    /// its identity instead of stealing another occurrence's positional slot.
    /// Leftovers pair in source order.
    private func pairChildren(_ old: [IRNode], _ new: [IRNode]) -> [Int?] {
        var oldByLabel: [String: [Int]] = [:]
        for (index, node) in old.enumerated() {
            oldByLabel[node.label, default: []].append(index)
        }
        var newByLabel: [String: [Int]] = [:]
        for (index, node) in new.enumerated() {
            newByLabel[node.label, default: []].append(index)
        }

        var result = [Int?](repeating: nil, count: new.count)
        for (label, newIndices) in newByLabel {
            var available = oldByLabel[label] ?? []
            for newIndex in newIndices {
                if let slot = available.firstIndex(where: { old[$0].hash == new[newIndex].hash }) {
                    result[newIndex] = available.remove(at: slot)
                }
            }
            for newIndex in newIndices where result[newIndex] == nil {
                if available.isEmpty { break }
                result[newIndex] = available.removeFirst()
            }
        }
        return result
    }

    private func diffNode(
        _ old: IRNode, _ new: IRNode,
        path: String,
        into changes: inout [IRChange]
    ) {
        // The hash covers the whole subtree's stable content — equal means
        // nothing below this point changed.
        guard old.hash != new.hash else { return }

        let propertyDiffs = diffProperties(old.properties, new.properties)
        if !propertyDiffs.isEmpty {
            changes.append(.nodeModified(path: path, properties: propertyDiffs))
        }
        diffForest(old.children, new.children, parentPath: path, into: &changes)
    }

    private func diffProperties(
        _ old: [String: IRProperty], _ new: [String: IRProperty]
    ) -> [PropertyDiff] {
        var diffs: [PropertyDiff] = []
        for key in Set(old.keys).union(new.keys).sorted() {
            switch (old[key], new[key]) {
            case let (nil, newProp?):
                diffs.append(PropertyDiff(
                    key: key,
                    kind: .added(new: newProp.value.scalarText, winner: newProp.winner)))
            case let (oldProp?, nil):
                diffs.append(PropertyDiff(
                    key: key, kind: .removed(old: oldProp.value.scalarText)))
            case let (oldProp?, newProp?) where oldProp.value != newProp.value:
                diffs.append(PropertyDiff(key: key, kind: .changed(
                    old: oldProp.value.scalarText, new: newProp.value.scalarText,
                    oldWinner: oldProp.winner, newWinner: newProp.winner)))
            default:
                break // unchanged
            }
        }
        return diffs
    }

    private func join(_ parent: String, _ label: String) -> String {
        parent.isEmpty ? label : "\(parent) > \(label)"
    }
}

// MARK: - Rendering

extension IRDiffer {
    /// Human-readable diff, `git diff`-flavored.
    public static func renderText(_ changes: [IRChange]) -> String {
        guard !changes.isEmpty else { return "documents identical\n" }
        var out = ""
        var affected = 0
        for change in changes {
            affected += 1
            switch change {
            case .nodeAdded(let path):
                out += "+ \(path)  (added)\n"
            case .nodeRemoved(let path):
                out += "- \(path)  (removed)\n"
            case .childrenReordered(let path):
                out += "± \(path)  (children reordered)\n"
            case let .nodeModified(path, properties):
                out += "~ \(path)\n"
                for diff in properties {
                    switch diff.kind {
                    case let .added(new, winner):
                        out += "    + \(diff.key): \(new)\n"
                        out += "          from: \(winner)\n"
                    case let .removed(old):
                        out += "    - \(diff.key): \(old)\n"
                    case let .changed(old, new, oldWinner, newWinner):
                        out += "    ~ \(diff.key): \(old) → \(new)\n"
                        out += "          was: \(oldWinner)\n"
                        out += "          now: \(newWinner)\n"
                    }
                }
            }
        }
        out += "\n\(affected) affected node(s)\n"
        return out
    }

    /// Machine-readable diff — the invalidation feed for incremental
    /// regeneration (`hypercode.diff/v1`).
    public static func renderJSON(_ changes: [IRChange]) -> String {
        let items: [Emitter.IR] = changes.map { change in
            switch change {
            case .nodeAdded(let path):
                return .object([("kind", .string("added")), ("node", .string(path))])
            case .nodeRemoved(let path):
                return .object([("kind", .string("removed")), ("node", .string(path))])
            case .childrenReordered(let path):
                return .object([("kind", .string("reordered")), ("node", .string(path))])
            case let .nodeModified(path, properties):
                let props: [Emitter.IR] = properties.map { diff in
                    switch diff.kind {
                    case let .added(new, winner):
                        return .object([
                            ("key", .string(diff.key)), ("kind", .string("added")),
                            ("new", .string(new)), ("winner", .string(winner)),
                        ])
                    case let .removed(old):
                        return .object([
                            ("key", .string(diff.key)), ("kind", .string("removed")),
                            ("old", .string(old)),
                        ])
                    case let .changed(old, new, oldWinner, newWinner):
                        return .object([
                            ("key", .string(diff.key)), ("kind", .string("changed")),
                            ("old", .string(old)), ("new", .string(new)),
                            ("oldWinner", .string(oldWinner)), ("newWinner", .string(newWinner)),
                        ])
                    }
                }
                return .object([
                    ("kind", .string("modified")), ("node", .string(path)),
                    ("properties", .array(props)),
                ])
            }
        }
        let root = Emitter.IR.object([
            ("version", .string("hypercode.diff/v1")),
            ("changes", .array(items)),
        ])
        return Emitter.json(root, indent: 0) + "\n"
    }
}
