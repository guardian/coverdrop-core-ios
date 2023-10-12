@testable import CoverDropCore
import XCTest

// swiftlint:disable force_try identifier_name

let KEY_LENGTH_IN_BYTES: Int = 32
let COVERDROP_KDF_SALT = "COVERDROPKDFSALT".asBytes()

final class PassphraseKDFTests: XCTestCase {
    func testCanDeriveKeyWithDefaultSalt() throws {
        let password = "password"

        let key = try PassphraseKDF.deriveKey(passphrase: password, keyLengthInBytes: KEY_LENGTH_IN_BYTES, salt: COVERDROP_KDF_SALT)

        XCTAssertEqual(
            key.key,
            [
                87, 142, 227, 118, 54, 191, 39, 234, 240, 138, 109, 90, 185, 79, 99, 0, 188, 69, 38, 101, 58, 35, 216, 224, 67, 229, 154, 166, 223, 206, 176, 98
            ]
        )
    }

    func testWillFailIfPasswordIsWrong() throws {
        let password_1 = "password"
        guard let key_1 = try? PassphraseKDF.deriveKey(passphrase: password_1, keyLengthInBytes: KEY_LENGTH_IN_BYTES, salt: COVERDROP_KDF_SALT) else {
            XCTFail("Failed to derive key from password")
            return
        }

        let password_2 = "a different password"
        guard let key_2 = try? PassphraseKDF.deriveKey(passphrase: password_2, keyLengthInBytes: KEY_LENGTH_IN_BYTES, salt: COVERDROP_KDF_SALT) else {
            XCTFail("Failed to derive key from password")
            return
        }

        XCTAssertNotEqual(key_1.key, key_2.key)
    }

    func testWillFailIfSaltIsDifferent() throws {
        let password = "password"

        let salt_1 = "COVERDROPKDFSALT"
        let salt_2 = "MOVERDROPKDFSALT"

        guard let key_1 = try? PassphraseKDF.deriveKey(passphrase: password, keyLengthInBytes: KEY_LENGTH_IN_BYTES, salt: salt_1.asBytes()),
              let key_2 = try? PassphraseKDF.deriveKey(passphrase: password, keyLengthInBytes: KEY_LENGTH_IN_BYTES, salt: salt_2.asBytes())
        else {
            XCTFail("Failed to derive key from password")
            return
        }

        XCTAssertNotEqual(key_1.key, key_2.key)
    }

    func testWillThrowIfPassphraseEmpty() throws {
        XCTAssertThrowsError(try PassphraseKDF.deriveKey(passphrase: "", keyLengthInBytes: KEY_LENGTH_IN_BYTES, salt: COVERDROP_KDF_SALT)) { error in
            XCTAssertEqual(error as! KeyDerivationError, KeyDerivationError.passphraseEmpty)
        }
    }

    func testWillThrowIfKeyLengthNotPositive() throws {
        XCTAssertThrowsError(try PassphraseKDF.deriveKey(passphrase: "valid_password", keyLengthInBytes: 0, salt: COVERDROP_KDF_SALT)) { error in
            XCTAssertEqual(error as! KeyDerivationError, KeyDerivationError.keyLengthMustBePositive)
        }
    }

    func testWillThrowIfSaltLenghtNot16Bytes() throws {
        XCTAssertThrowsError(try PassphraseKDF.deriveKey(passphrase: "valid_password", keyLengthInBytes: KEY_LENGTH_IN_BYTES, salt: "too_short".asBytes())) { error in
            XCTAssertEqual(error as! KeyDerivationError, KeyDerivationError.saltIncorrectByteLength)
        }
    }
}
