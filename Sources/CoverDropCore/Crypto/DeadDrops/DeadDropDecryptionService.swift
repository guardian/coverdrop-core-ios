import Foundation

enum DeadDropDecryptionServiceError: Error {
    case failedToGetKeys
    case failedToGetDeadDrops
}

public struct DeadDropDecryptionService {
    public init() {}

    /// This service tries to decrypts the supplied verfied dead drops with the supplied journalist Key
    /// If a message within the dead drops is succesfully decrypted it is added to the user mailbox
    ///
    public func decryptStoredDeadDrops(secretDataRepository: SecretDataRepository = SecretDataRepository.shared,
                                       publicDataRepository: PublicDataRepository = PublicDataRepository.shared) async throws {
        guard let verifiedDeadDrops = try? await publicDataRepository.loadDeadDrops() else {
            throw DeadDropDecryptionServiceError.failedToGetDeadDrops
        }

        guard let verifiedPublicKeys = try? await publicDataRepository.loadAndVerifyPublicKeys() else {
            throw DeadDropDecryptionServiceError.failedToGetKeys
        }

        // we only have access to the user secret key when we are unlocked
        // so this is the only state we can be in to try and decrypt the data
        if case let .unlockedSecretData(unlockedData: secretData) = await secretDataRepository.secretData {
            let userSecretKey = await MainActor.run { () -> SecretEncryptionKey<User> in
                secretData.unlockedData.userKey.secretKey
            }

            let currentConversationJournalists = await secretData.getMailboxRecipients()

            var messages: Set<Message> = []
            for journalistData in currentConversationJournalists {
                let message = await DecryptedDeadDrops.decryptWithUserKey(userSecretKey: userSecretKey, journalistData: journalistData, verifiedDeadDropData: verifiedDeadDrops, verifiedPublicKeys: verifiedPublicKeys)
                messages.formUnion(message)
            }

            try await secretData.addMessages(messages: messages)
        }
    }
}
