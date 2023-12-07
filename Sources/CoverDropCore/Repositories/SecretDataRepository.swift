import CryptoKit
import Foundation
import Sodium

@MainActor
public class SecretDataRepository: ObservableObject {
    @Published public var secretData: SecretData = .lockedSecretData(lockedData: LockedSecretData())
    private var encryptedStorageSession: EncryptedStorageSession?

    public static let shared = SecretDataRepository()
    private init() {
        // Making the initialiser private is a way to achieve the sington pattern
    }

    public func createOrReset(passphrase: ValidPassword) async throws {
        self.encryptedStorageSession = try await EncryptedStorage.createOrResetStorageWithPassphrase(passphrase: passphrase)
        try await self.loadData()
    }

    public func unlock(passphrase: ValidPassword) async throws {
        // unlock session and use it to load the inital data
        self.encryptedStorageSession = try await EncryptedStorage.unlockStorageWithPassphrase(passphrase: passphrase)
        try await self.loadData()
    }

    private func loadData() async throws {
        let unlockedData = try await EncryptedStorage.loadStorageFromDisk(session: self.encryptedStorageSession!)
        self.secretData = .unlockedSecretData(unlockedData: unlockedData)
    }

    public func lock(unlockedData: UnlockedSecretData) async throws {
        try await storeData(unlockedData: unlockedData)
        self.secretData = .lockedSecretData(lockedData: LockedSecretData())

    }

    public func storeData(unlockedData: UnlockedSecretData) async throws {
        self.secretData = .unlockedSecretData(unlockedData: unlockedData)
        try await EncryptedStorage.updateStorageOnDisk(session: self.encryptedStorageSession!, state: unlockedData)
    }
}
