import CryptoKit
import Foundation
import Sodium

public struct Storage: Codable {
    var salt: [UInt8]
    var initialisationVector: [UInt8]
    public var blobData: BlobData?
    public var lastModified: Date?
    public var creationDate: Date?
    public var privateSendingQueueSecret: PrivateSendingQueueSecret
}

public enum BlobData: Codable {
    case encrypted(blob: Data)
    case plaintext(blob: UnlockedSecretData)
}

enum EncryptedStorageError: Error {
    case unsupportedAlgorithm
    case keyMissing
    case blobMissing
    case saltGenerationFailed
    case secureEnclaveRequiresKey
    case tryingToDecryptPlaintext
    case encryptionFailed
    case decryptionFailed
}

public actor EncryptedStorage {
    public static let fileName = "coverdrop"
    public static let storagePaddingToSize = 1 * 1024 * 1024 // 1 Mib
    public static let xsalsa20KeyLength = 32

    /// To be called on every app start. If no storage exists, a new one is created with an undisclosed passphrase. If one already exists, its last-modified date is updated.
    /// - Parameters:
    ///  - withSecureEnclave: is present to allow easier testing on non-secure enclave devices
    /// - Returns: `Storage` object with encrypted `blob`
    /// - Throws: if touching or creating storage fails

    public static func onAppStart(withSecureEnclave: Bool) async throws -> Storage {
        let fileURL = try EncryptedStorage.secureStorageFileURL()

        if FileManager.default.fileExists(atPath: fileURL.path) {
            return try touchExistingStorage(fileUrl: fileURL)
        } else {
            /// We get here if there was no existing storage
            if withSecureEnclave, SecureEnclave.isAvailable {
                return try await createInitialStorageWithRandomPassphrase(withSecureEnclave: withSecureEnclave)
            } else {
                return try await createInitialStorageWithRandomPassphrase(withSecureEnclave: false)
            }
        }
    }

    /// This will update the modification date on the on-Disk storage file to the current datetime.
    /// To make sure this is done correctly we set the `modificationDate`and `creationDate` attributes, and then read the attribute again
    /// - Parameters:
    ///  - fileUrl: the `URL` of the storage file to write to
    /// - Returns: `Storage` object with encrypted `blob`
    /// - Throws: if attribute setting / retreval or JSON decoding fail

    static func touchExistingStorage(fileUrl: URL) throws -> Storage {
        let data = try Data(contentsOf: fileUrl)
        let date = NSDate()

        try FileManager.default.setAttributes([FileAttributeKey.modificationDate: date], ofItemAtPath: fileUrl.path)
        // updating creation date of file too to obfuscate the inital creation date
        try FileManager.default.setAttributes([FileAttributeKey.creationDate: date], ofItemAtPath: fileUrl.path)

        let attributes: [FileAttributeKey: Any] = try FileManager.default.attributesOfItem(atPath: fileUrl.path)

        let modificationDate = attributes[FileAttributeKey.modificationDate] as? Date
        let creationDate = attributes[FileAttributeKey.creationDate] as? Date
        var storage = try JSONDecoder().decode(Storage.self, from: data)

        storage.lastModified = modificationDate
        storage.creationDate = creationDate

        return storage
    }

    /// This is called if no storage file exists, this should only happen the first time the user opens the app after coverdrop is enabled.
    /// - Parameters:
    ///   - withSecureEnclave: is present to allow easier testing on non-secure enclave devices
    /// - Returns: `Storage` object with `plaintext` `blobData`
    /// - Throws: if the writing the storage fails

    public static func createInitialStorageWithRandomPassphrase(withSecureEnclave: Bool) async throws -> Storage {
        let passphrase = newStoragePassphrase()
        let userKeyPair: EncryptionKeypair<User> = try EncryptionKeypair<User>.generateEncryptionKeypair()
        return try await createNewStorageWithPassphrase(passphrase: passphrase, withSecureEnclave: withSecureEnclave, userKeyPair: userKeyPair)
    }

    public static func initialiseStorage() throws -> Storage {
        let salt = PassphraseKDF.getSalt()
        let initialisationVector = Sodium().stream.nonce()
        let date = NSDate() as Date
        let privateSendingQueueSecret = try PrivateSendingQueueSecret.fromSecureRandom()
        if let mySalt = salt {
            return Storage(salt: mySalt, initialisationVector: initialisationVector, lastModified: date, creationDate: date, privateSendingQueueSecret: privateSendingQueueSecret)
        } else {
            throw EncryptedStorageError.saltGenerationFailed
        }
    }

    /// This is called when there is existing storage, but the user enters the wrong passphrase
    /// - Parameters:
    ///   - passphras: the new passphrase created by the user
    ///   - withSecureEnclave: is present to allow easier testing on non-secure enclave devices
    /// - Returns: `Storage` object with `plaintext` `blobData`
    /// - Throws: if the writing the storage fails

    public static func createNewStorageWithPassphrase(passphrase: ValidPassword, withSecureEnclave: Bool, userKeyPair: EncryptionKeypair<User>) async throws -> Storage {
        let secureEnclaveKey = withSecureEnclave ? try await SecureEnclavePrivateKey.createKey(name: fileName) : nil

        let storage = try initialiseStorage()

        let state = await UnlockedSecretData(passphrase: passphrase, messageMailbox: [], userKey: userKeyPair, privateSendingQueueSecret: storage.privateSendingQueueSecret)

        return try await EncryptedStorage.updateStorageOnDisk(
            storage: storage,
            passphrase: passphrase,
            newState: state,
            withSecureEnclave: withSecureEnclave,
            secureEnclaveKey: secureEnclaveKey
        )
    }

    /// Reads the storage from disk. Where applicable the secure element is used.
    /// - Parameters:
    ///  - passphrase:  of type `ValidPassword` is the passphrase supplied by the user to decrypt the storage
    ///  - withSecureEnclave: is present to allow easier testing on non-secure enclave devices
    /// - Returns: `Storage` object with `plaintext` `blobData`
    /// - Throws: If the storage cannot be decrypted (e.g. wrong passphrase)

    public static func loadStorageFromDisk(passphrase: ValidPassword, withSecureEnclave: Bool, secureEnclaveKey: SecureEnclavePrivateKey? = nil) async throws -> Storage {
        // If we are using the secure element, we must also supply a `SecureEnclavePrivateKey`
        if withSecureEnclave, secureEnclaveKey == nil {
            throw EncryptedStorageError.secureEnclaveRequiresKey
        }

        let fileURL = try EncryptedStorage.secureStorageFileURL()
        let readData = try Data(contentsOf: fileURL)
        var storage: Storage = try JSONDecoder().decode(Storage.self, from: readData)

        let kUser: UnauthenticatedStreamCipherKey = try PassphraseKDF.deriveKey(passphrase: passphrase.password, keyLengthInBytes: xsalsa20KeyLength, salt: storage.salt)

        guard let storageContents = storage.blobData else { throw EncryptedStorageError.blobMissing }
        switch storageContents {
        case .plaintext:
            throw EncryptedStorageError.tryingToDecryptPlaintext
        case let .encrypted(data):

            if withSecureEnclave, SecureEnclave.isAvailable, let secureEnclaveKey {
                let blob = try await decryptStorageWithSecureEnclaveKeyAndUserSuppliedKey(cipherText: data, initialisationVector: storage.initialisationVector, kUser: kUser, secureEnclaveKey: secureEnclaveKey)

                let decodedBlob = try await UnlockedSecretData.fromUnencryptedBytes(bytes: Array(blob))
                storage.blobData = .plaintext(blob: decodedBlob)
                return storage
            } else {
                let blob = try decryptStorageWithUserSuppliedKeyOnly(cipherText: Array(data), initialisationVector: storage.initialisationVector, kUser: kUser)
                let decodedBlob = try await UnlockedSecretData.fromUnencryptedBytes(bytes: Array(blob))
                storage.blobData = .plaintext(blob: decodedBlob)
                return storage
            }
        }
    }

    /// Writes the new state to the storage with the given passphrase. Where applicable the secure element is used.
    ///  - Parameters:
    ///   - storage: is a existing `Storage` object
    ///   - passphrase: a `ValidPassword` supplied by the users
    ///   - newState: a `[UInt8]` byte array of the new state we want to update storage with, Any existing data will be overwritten.
    ///   - withSecureEnclave: is present to allow easier testing on non-secure enclave devices
    ///   - secureElementHandle: an `Optional` `SecureEnclavePrivateKey` if we are using the secure enclave
    ///  - Returns: `Storage` with `encrypted` `blobData`
    ///  - Throws: if password derivation, key loading, encryption, json encoding or file writing fail

    public static func updateStorageOnDisk(storage: Storage, passphrase: ValidPassword, newState: UnlockedSecretData, withSecureEnclave: Bool, secureEnclaveKey: SecureEnclavePrivateKey? = nil) async throws -> Storage {
        // If we are using the secure element, we must also supply a `SecureEnclavePrivateKey`
        if withSecureEnclave, secureEnclaveKey == nil {
            throw EncryptedStorageError.secureEnclaveRequiresKey
        }

        // Pad the new state to a fixed size
        var newStatePadded: [UInt8] = await newState.asUnencryptedBytes()
        Sodium().utils.pad(bytes: &newStatePadded, blockSize: storagePaddingToSize)

        var newStorage = storage // assign to var so we can modify later

        let kUser: UnauthenticatedStreamCipherKey = try PassphraseKDF.deriveKey(passphrase: passphrase.password, keyLengthInBytes: xsalsa20KeyLength, salt: newStorage.salt)

        let outfile = try secureStorageFileURL()

        if withSecureEnclave, SecureEnclave.isAvailable, let secureEnclaveKey {
            let cipherText = try encryptStorageWithSecureEnclaveKeyAndUserSuppliedKey(plainText: newStatePadded, storage: newStorage, kUser: kUser, secureEnclaveKey: secureEnclaveKey)
            newStorage.blobData = .encrypted(blob: Data(cipherText))
            let jsonData = try JSONEncoder().encode(newStorage)
            try jsonData.write(to: outfile, options: .completeFileProtection)
            return newStorage
        } else {
            let messageData = newStatePadded

            guard let encryptedData = Sodium().secretBox.seal(message: messageData, secretKey: kUser.key, nonce: newStorage.initialisationVector)
            else { throw EncryptionError.failedToEncrypt }

            newStorage.blobData = .encrypted(blob: Data(encryptedData))
            let jsonData = try JSONEncoder().encode(newStorage)
            try jsonData.write(to: outfile, options: .completeFileProtection)
            return newStorage
        }
    }

    /// encrypt the secure storage with Secure Enclave Key and User supplied key.
    /// As per [Client data structures and algorithms](https://github.com/guardian/coverdrop/blob/main/docs/client_data_structures_and_algorithms.md) we encrypt the `cipherText`
    /// first with the user supplied `UnauthenticatedStreamCipherKey` from the users passphrase
    /// - Parameters:
    ///  - plainText: `[UInt8]` of the plaintext to encrypt
    ///  - storage: `Storage` element we want to encrypt data for
    ///  - kUser: `UnauthenticatedStreamCipherKey`
    ///  - withSecureEnclave: is present to allow easier testing on non-secure enclave devices
    ///  - secureElementHandle: an `Optional` `SecureEnclavePrivateKey` if we are using the secure enclave
    /// - Returns: `Data` encrypted ciphertext
    /// - Throws: if key loading, unauthenticated encryption, secure element encryption, or unpadding fail

    public static func encryptStorageWithSecureEnclaveKeyAndUserSuppliedKey(plainText: [UInt8], storage: Storage, kUser: UnauthenticatedStreamCipherKey, secureEnclaveKey: SecureEnclavePrivateKey) throws -> Data {
        guard let publicKey = SecKeyCopyPublicKey(secureEnclaveKey.privateKey) else { throw EncryptedStorageError.keyMissing }
        let innerEncryptedData: [UInt8] = try SecureEnclaveEncryption.authenticatedEncrypt(key: publicKey, plainText: plainText)
        let outerEncryptedData: [UInt8] = try UnauthenticatedStreamCipherXSalsa20.encrypt(key: kUser, plainText: innerEncryptedData, initialisationVector: storage.initialisationVector) // important: MUST NOT be authenticated!
        return Data(outerEncryptedData)
    }

    /// Decrypt the secure storage with Secure Enclave Key and User supplied key.
    /// As per [Client data structures and algorithms](https://github.com/guardian/coverdrop/blob/main/docs/client_data_structures_and_algorithms.md) we decrypt the `cipherText`
    /// first with the user supplied `UnauthenticatedStreamCipherKey` from the users passphrase
    /// - Parameters:
    ///  - cipherText: `Data` of the ciphertext to decrypt
    ///  - iv: `[UInt8]` of the initialisation vector used to encrypt the ciphertext
    ///  - kUser: `UnauthenticatedStreamCipherKey`
    /// - Returns: `Data` of the decrypted ciphertext
    /// - Throws: if key loading, unauthenticated decryption, secure element decryption, or unpadding fail

    public static func decryptStorageWithSecureEnclaveKeyAndUserSuppliedKey(cipherText: Data, initialisationVector: [UInt8], kUser: UnauthenticatedStreamCipherKey, secureEnclaveKey: SecureEnclavePrivateKey) async throws -> Data {
        let decryptedData = try UnauthenticatedStreamCipherXSalsa20.decrypt(key: kUser, cipherText: Array(cipherText), initialisationVector: initialisationVector) // important: MUST NOT be authenticated!
        var newStatePadded = try SecureEnclaveEncryption.authenticatedDecrypt(key: secureEnclaveKey.privateKey, cipherText: decryptedData)
        Sodium().utils.unpad(bytes: &newStatePadded, blockSize: EncryptedStorage.storagePaddingToSize)
        return Data(newStatePadded)
    }

    /// Decrypt the secure storage `blobData` with the user supplied key only
    /// As per [Client data structures and algorithms](https://github.com/guardian/coverdrop/blob/main/docs/client_data_structures_and_algorithms.md) we decrypt the `cipherText`
    /// first with the user supplied `UnauthenticatedStreamCipherKey` only,  we then unpad the resulting byte array
    /// - Parameters:
    ///  - cipherText: is the `Data` (an Apple byte array) normally loaded from the encrypted storage `blob`
    ///  - iv: is a `Sodium().stream.nonce()` byte array, again this is normally available in the `Storage` object
    ///  - kUser: is the  `UnauthenticatedStreamCipherKey` from the users passphrase
    /// - Returns: `Data` of the decypted ciphertext
    /// - Throws: if authenticated decryption, or unpadding fail

    public static func decryptStorageWithUserSuppliedKeyOnly(cipherText: [UInt8], initialisationVector: [UInt8], kUser: UnauthenticatedStreamCipherKey) throws -> Data {
        guard let decryptedData = Sodium().secretBox.open(authenticatedCipherText: cipherText, secretKey: kUser.key, nonce: initialisationVector) else {
            throw EncryptionError.failedToDecrypt
        }

        var newStatePadded = decryptedData
        Sodium().utils.unpad(bytes: &newStatePadded, blockSize: EncryptedStorage.storagePaddingToSize)

        return Data(newStatePadded)
    }

    /// Generates a `URL` to the secure storage file
    /// - Returns: `URL` to the secure storage file
    /// - Throws: if the `URL` cannot be generated

    public static func secureStorageFileURL() throws -> URL {
        return try FileHelper.getPath(fileName: fileName)
    }

    /// Creates a new passphrase. If no secure element is available, it will be more complex (of higher entropy) to
    /// withstand brute-force attacks without the help of rate limiting.
    /// - Parameters:
    ///  - withSecureEnclave: is present to allow easier testing on non-secure enclave devices
    /// - Returns: `ValidPassword` with the relevant word count

    public static func newStoragePassphrase(withSecureEnclave: Bool = true) -> ValidPassword {
        let generator = PasswordGenerator.shared

        if withSecureEnclave, SecureEnclave.isAvailable {
            return generator.generate(wordCount: ApplicationConfig.config.passphraseLowWordCount)
        } else {
            return generator.generate(wordCount: ApplicationConfig.config.passphraseHighWordCount)
        }
    }
}
