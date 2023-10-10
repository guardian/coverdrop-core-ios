import CryptoKit
import Foundation
import Sodium

enum SecureEnclaveEncryption {
    /// Performs a `AES GCM` encryption using the `eciesEncryptionCofactorVariableIVX963SHA256AESGCM` algorithm
    /// on the supplied `plainText` using the Apple `SecureEnclave` with the `SecKey` key.
    /// `throws` if the `eciesEncryptionCofactorVariableIVX963SHA256AESGCM` algorithm is unsupported by the supplied key,
    /// or if encrytion fails
    /// returns a encypted byte array

    public static func authenticatedEncrypt(key: SecKey, plainText: [UInt8]) throws -> [UInt8] {
        let algorithm: SecKeyAlgorithm = .eciesEncryptionCofactorVariableIVX963SHA256AESGCM

        guard SecKeyIsAlgorithmSupported(key, .encrypt, algorithm) else {
            throw EncryptedStorageError.unsupportedAlgorithm
        }
        var error: Unmanaged<CFError>?
        let plainTextData = Data(plainText)
        guard let cipherTextData = (SecKeyCreateEncryptedData(key, algorithm,
                                                              plainTextData as CFData,
                                                              &error) as Data?)
        else { throw EncryptionError.failedToEncrypt }
        return Array(cipherTextData)
    }

    /// Performs a `AES GCM` decryption using the `eciesEncryptionCofactorVariableIVX963SHA256AESGCM` algorithm
    /// on the supplied `cipherText` using the Apple `SecureEnclave` with the `SecKey` key.
    /// `throws` if the `eciesEncryptionCofactorVariableIVX963SHA256AESGCM` algorithm is unsupported by the supplied key,
    /// or if decrytion fails
    /// returns a padded decypted byte array

    public static func authenticatedDecrypt(key: SecKey, cipherText: [UInt8]) throws -> [UInt8] {
        let algorithm: SecKeyAlgorithm = .eciesEncryptionCofactorVariableIVX963SHA256AESGCM

        guard SecKeyIsAlgorithmSupported(key, .decrypt, algorithm) else {
            throw EncryptedStorageError.unsupportedAlgorithm
        }
        var error: Unmanaged<CFError>?
        let cipherTextData = Data(cipherText)
        if let plainTextData = (SecKeyCreateDecryptedData(key, algorithm,
                                                          cipherTextData as CFData,
                                                          &error) as Data?)
        {
            return Array(plainTextData)
        } else {
            throw EncryptionError.failedToDecrypt
        }
    }
}
