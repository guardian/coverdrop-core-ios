import CryptoKit
import Foundation
import Sodium

@MainActor
public class SecretDataRepository: ObservableObject {
    @Published public var secretData: SecretData = .lockedSecretData(lockedData: LockedSecretData(encryptedData: "".asBytes()))
    // Making the initialiser private is a way to achieve the sington pattern
    private init() {
        // Create a Task and do any async stuff for this here.
    }

    public static let shared = SecretDataRepository()
    public func unlock(passphrase: ValidPassword) async throws -> Bool {
        do {
            let key = try await SecureEnclavePrivateKey.loadKey(name: EncryptedStorage.fileName)
            // load data from Encrypted Storage
            let storage: Storage = try await EncryptedStorage.loadStorageFromDisk(passphrase: passphrase, withSecureEnclave: SecureEnclave.isAvailable, secureEnclaveKey: key)

            if case let .plaintext(unlockedSecretData) = storage.blobData {
                secretData = .unlockedSecretData(unlockedData: unlockedSecretData)
                return true
            } else {
                return false
            }
        } catch {
            return false
        }
    }

    public func saveMessages(data: UnlockedSecretData, withSecureEnclave: Bool) async throws -> Storage {
        let storage = try EncryptedStorage.initialiseStorage()
        let key = try await SecureEnclavePrivateKey.loadKey(name: EncryptedStorage.fileName)
        let newData = try await EncryptedStorage.updateStorageOnDisk(storage: storage, passphrase: data.passphrase, newState: data, withSecureEnclave: withSecureEnclave, secureEnclaveKey: key)
        return newData
    }

    public func lock(data: UnlockedSecretData, withSecureEnclave: Bool) async throws {
        let savedData = try await saveMessages(data: data, withSecureEnclave: withSecureEnclave)
        if case let .encrypted(lockedData) = savedData.blobData {
            secretData = .lockedSecretData(lockedData: LockedSecretData(encryptedData: Array(lockedData)))
        }
    }
}
