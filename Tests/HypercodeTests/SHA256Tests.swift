import XCTest
@testable import Hypercode

// NIST FIPS 180-4 example vectors.
final class SHA256Tests: XCTestCase {
    func testEmptyString() {
        // SHA-256("") = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
        XCTAssertEqual(
            SHA256.hash(utf8: "").hexString,
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        )
    }

    func testABC() {
        // SHA-256("abc") — verified with shasum -a 256 and OpenSSL
        XCTAssertEqual(
            SHA256.hash(utf8: "abc").hexString,
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
    }

    func testLongMessage() {
        // SHA-256("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq")
        // = 248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1
        XCTAssertEqual(
            SHA256.hash(utf8: "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq").hexString,
            "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"
        )
    }
}
