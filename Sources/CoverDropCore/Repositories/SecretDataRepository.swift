import CryptoKit
import Foundation
import Sodium

enum SecretDataRepositoryError: Error {
    case secretDataIsLocked
    case repositoriesNotAvailable
}

public protocol SecretDataRepositoryProtocol {
    func getSecretData() -> SecretData
    func createOrReset(passphrase: ValidPassword) async throws
    func lock() async throws
    func unlock(passphrase: ValidPassword) async throws
    func getMailboxRecipients(publicKeyData: VerifiedPublicKeys) async throws -> [JournalistData]
    func addMessage(message: Message) async throws
    func addMessages(messages: Set<Message>) async throws
    func sendMessage(
        _ message: String,
        to recipient: JournalistData,
        dateSent: Date
    ) async throws
}

public class SecretDataRepository: ObservableObject, SecretDataRepositoryProtocol {
    @Published public var secretData: SecretData = .lockedSecretData(lockedData: LockedSecretData())
    private var publicDataRepository: PublicDataRepository

    init(publicDataRepository: PublicDataRepository) {
        self.publicDataRepository = publicDataRepository
    }

    private var encryptedStorageSession: EncryptedStorageSession?

    public func getSecretData() -> SecretData {
        return secretData
    }

    public func createOrReset(passphrase: ValidPassword) async throws {
        encryptedStorageSession = try await EncryptedStorage.createOrResetStorageWithPassphrase(passphrase: passphrase)
        try await loadData()
    }

    public func unlock(passphrase: ValidPassword) async throws {
        // unlock session and use it to load the inital data
        encryptedStorageSession = try await EncryptedStorage.unlockStorageWithPassphrase(passphrase: passphrase)
        try await loadData()
        try await decryptDeadDrops()
    }

    private func decryptDeadDrops() async throws {
        try await DeadDropDecryptionService().decryptStoredDeadDrops(
            publicDataRepository: publicDataRepository,
            secretDataRepository: self
        )
    }

    private func loadData() async throws {
        let unlockedData = try await EncryptedStorage.loadStorageFromDisk(session: encryptedStorageSession!)
        await MainActor.run {
            secretData = .unlockedSecretData(unlockedData: unlockedData)
        }
    }

    public func lock() async throws {
        try await storeData()
        await MainActor.run {
            secretData = .lockedSecretData(lockedData: LockedSecretData())
        }
    }

    public func storeData() async throws {
        if case let .unlockedSecretData(unlockedData: unlockedData) = secretData {
            try EncryptedStorage.updateStorageOnDisk(session: encryptedStorageSession!, state: unlockedData)
        }
    }

    public func sendMessage(
        _ message: String,
        to recipient: JournalistData,
        dateSent: Date
    ) async throws {
        // add the current message to the private sending queue and
        // secret Data  Repository

        guard case let .unlockedSecretData(unlockedData: unlockedData) = secretData else {
            throw SecretDataRepositoryError.secretDataIsLocked
        }

        guard let lib = try? CoverDropService.getLibrary() else {
            throw SecretDataRepositoryError.repositoriesNotAvailable
        }

        let encryptedMessage = try await UserToCoverNodeMessageData.createMessage(
            message: message,
            messageRecipient: recipient,
            verifiedPublicKeys: lib.publicDataRepository.getVerifiedKeysOrThrow(),
            userPublicKey: unlockedData.userKey.publicKey
        )

        let hint = try await PrivateSendingQueueRepository.shared.enqueue(
            secret: unlockedData.privateSendingQueueSecret,
            message: encryptedMessage
        )

        let outboundMessage = await OutboundMessageData(
            recipient: recipient,
            messageText: message,
            dateQueued: dateSent,
            hint: hint
        )

        let newMessage: Message = .outboundMessage(message: outboundMessage)
        try await addMessage(message: newMessage)
    }

    public func addMessage(message: Message) async throws {
        if case let .unlockedSecretData(unlockedData: unlockedData) = secretData {
            await unlockedData.addMessage(message: message)
            try await storeData()
        }
    }

    public func addMessages(messages: Set<Message>) async throws {
        if case let .unlockedSecretData(unlockedData: unlockedData) = secretData {
            await unlockedData.addMessages(messages: messages)
            try await storeData()
        }
    }

    /// This gets the journalist or desks that the user has had converstations with
    /// This is used when we decrypt incoming dead drops so that we only try with keys for journalists
    /// we've been in converstations with.
    /// - Returns: A list of JournalistKeyData
    public func getMailboxRecipients(publicKeyData: VerifiedPublicKeys) async throws -> [JournalistData] {
        guard case let .unlockedSecretData(unlockedData: unlockedData) = secretData else {
            throw SecretDataRepositoryError.secretDataIsLocked
        }
        let recipients = unlockedData.messageMailbox.compactMap { message in
            switch message {
            case let .outboundMessage(message: message):
                return message.recipient
            case let .incomingMessage(message: messageType):
                switch messageType {
                case let .textMessage(message: message):
                    return message.sender
                case let .handoverMessage(message: handover):
                    return publicKeyData.getJournalistKeyDataForJournalistId(
                        journalistId: handover.handoverTo
                    )
                }
            }
        }
        let uniqueRecipients = Set(recipients)
        return Array(uniqueRecipients)
    }

    func setUnlockedDataForTesting(unlockedData: UnlockedSecretData) {
        secretData = .unlockedSecretData(unlockedData: unlockedData)
    }
}
