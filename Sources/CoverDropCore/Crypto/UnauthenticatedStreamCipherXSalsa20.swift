import CryptoKit
import Foundation
import Sodium

enum UnauthenticatedStreamCipherXSalsa20 {
    /// Performs a `XSalsa20` unauthenticated stream encryption on the given `plainText` byte array
    /// using the supplied `key`. The `key` should be a `UnauthenticatedStreamCipherKey`
    /// `iv` is a `Sodium().stream.nonce()` byte array
    /// Note that performing a `XSalsa20` twice on a given clear text produces the original clear text,
    /// This is why the `unauthenticatedDecrypt` performs the same `Sodium().stream.xor`
    /// These functions have been seperated for readability and comprehension.
    /// returns the decrypted data as a byte array

    public static func encrypt(key: UnauthenticatedStreamCipherKey, plainText: [UInt8], initialisationVector: [UInt8]) throws -> [UInt8] {
        guard let encryptedData = Sodium().stream.xor(input: plainText, nonce: initialisationVector, secretKey: key.key) else {
            throw EncryptedStorageError.encryptionFailed
        }
        return encryptedData
    }

    /// Performs a `XSalsa20` unauthenticated stream decryption on the given `cipherText` byte array
    /// using the supplied `key`. The `key` should be a `UnauthenticatedStreamCipherKey`
    /// `iv` is a `Sodium().stream.nonce()` byte array
    /// returns the decrypted data as a byte array

    public static func decrypt(key: UnauthenticatedStreamCipherKey, cipherText: [UInt8], initialisationVector: [UInt8]) throws -> [UInt8] {
        guard let decryptedData = Sodium().stream.xor(input: cipherText, nonce: initialisationVector, secretKey: key.key) else {
            throw EncryptedStorageError.decryptionFailed
        }
        return decryptedData
    }
}
