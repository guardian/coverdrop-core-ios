import Foundation

enum DeadDropDecryptionServiceError: Error {
    case failedToGetKeysOrDeadDrops
}

public struct DeadDropDecryptionService {
    public init() {}

    /// This service tries to decrypts the supplied verfied dead drops with the supplied journalist Key
    /// If a message within the dead drops is succesfully decrypted it is added to the user mailbox
    ///
    public func decryptStoredDeadDrops(secretDataRepository: SecretDataRepository = SecretDataRepository.shared,
                                       publicDataRepository: PublicDataRepository = PublicDataRepository.shared, dateReceived: Date) async throws {
        let journalistPublicKeys: [String: [VerifiedJournalistPublicKeysGroup]]? = publicDataRepository.verifiedPublicKeysData?.allPublicKeysForJournalistsFromAllHierarchies()

        let profiles = publicDataRepository.verifiedPublicKeysData?.journalistProfiles

        guard let verifiedDeadDrops = publicDataRepository.deadDrops
        else {
            throw DeadDropDecryptionServiceError.failedToGetKeysOrDeadDrops
        }

        // we only have access to the user secret key when we are unlocked
        // so this is the only state we can be in to try and decrypt the data
        if case .unlockedSecretData(unlockedData: let secretData) = await secretDataRepository.secretData {
            let userSecretKey = await MainActor.run { () -> SecretEncryptionKey<User> in
                secretData.userKey.secretKey
            }

            let currentConversationJournalists = await secretData.getMailboxRecipients()

            var messages: Set<Message> = []
            for key in currentConversationJournalists {
                let message = await DecryptedDeadDrops.decryptWithUserKey(userSecretKey: userSecretKey, journalistKey: key, verifiedDeadDropData: verifiedDeadDrops, dateReceived: dateReceived)
                messages.formUnion(message)
            }

            await secretData.addMessages(messages: messages)
        }
    }
}
