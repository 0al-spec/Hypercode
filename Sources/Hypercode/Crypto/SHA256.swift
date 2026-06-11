import Crypto

// Thin wrapper around swift-crypto's SHA256 so the rest of the library uses a
// stable internal interface. swift-crypto mirrors the CryptoKit API and works
// on Linux (decision R11); on Apple platforms it delegates to CryptoKit.

struct SHA256Digest {
    let bytes: [UInt8]

    var hexString: String {
        let digits = Array("0123456789abcdef")
        var out = ""
        out.reserveCapacity(bytes.count * 2)
        for byte in bytes {
            out.append(digits[Int(byte >> 4)])
            out.append(digits[Int(byte & 0x0F)])
        }
        return out
    }
}

enum SHA256 {
    static func hash(_ input: [UInt8]) -> SHA256Digest {
        let digest = Crypto.SHA256.hash(data: input)
        return SHA256Digest(bytes: Array(digest))
    }

    static func hash(utf8 string: String) -> SHA256Digest {
        hash(Array(string.utf8))
    }
}
