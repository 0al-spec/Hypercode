import CryptoKit

// Thin wrapper around CryptoKit.SHA256 so the rest of the library uses a
// stable internal interface. CryptoKit is available on all supported targets
// (macOS 10.15+; this package requires macOS 13).

struct SHA256Digest {
    let bytes: [UInt8]

    var hexString: String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }
}

enum SHA256 {
    static func hash(_ input: [UInt8]) -> SHA256Digest {
        let digest = CryptoKit.SHA256.hash(data: input)
        return SHA256Digest(bytes: Array(digest))
    }

    static func hash(utf8 string: String) -> SHA256Digest {
        hash(Array(string.utf8))
    }
}
