import Foundation
import Sodium

enum KeyDerivationError: Error {
    case passphraseEmpty
    case keyLengthMustBePositive
    case hashFailure
    case saltIncorrectByteLength
}

enum DefaultStorageKeys {
    static let kdfSaltStorageKey = "kdfSaltStorageKey"
}

public struct UnauthenticatedStreamCipherKey {
    let key: [UInt8]
}

public enum PassphraseKDF {
    public static func deriveKey(passphrase: String, keyLengthInBytes: Int, salt: [UInt8]) throws -> UnauthenticatedStreamCipherKey {
        if passphrase.isEmpty { throw KeyDerivationError.passphraseEmpty }
        if keyLengthInBytes <= 0 { throw KeyDerivationError.keyLengthMustBePositive }
        // The salt must be 16 bytes long, this check is done internally in the `hash` function,
        // but a useful error is not thrown, hence the extra check here
        if salt.count != Sodium().pwHash.SaltBytes { throw KeyDerivationError.saltIncorrectByteLength }

        if let hash = Sodium().pwHash.hash(
            outputLength: keyLengthInBytes,
            passwd: passphrase.asBytes(),
            salt: salt,
            // TODO: These options need to be optimised, tracking issue https://github.com/guardian/coverdrop/issues/329
            opsLimit: Sodium().pwHash.OpsLimitModerate,
            memLimit: Sodium().pwHash.MemLimitModerate,
            alg: .Argon2ID13
        ) {
            return UnauthenticatedStreamCipherKey(key: hash)
        } else {
            throw KeyDerivationError.hashFailure
        }
    }

    /// Generated a new salt, or retrives the existing salt from `UserDefaults` local storage using

    static func getSalt() -> [UInt8]? {
        let defaults = UserDefaults.standard

        if let kdfSaltStorageKey = defaults.data(forKey: DefaultStorageKeys.kdfSaltStorageKey) {
            return Array(kdfSaltStorageKey)
        } else {
            let newSalt = randomSaltBytes(length: Sodium().pwHash.SaltBytes)
            defaults.set(NSData(bytes: newSalt, length: Sodium().pwHash.SaltBytes), forKey: DefaultStorageKeys.kdfSaltStorageKey)
            return newSalt
        }
    }
}
