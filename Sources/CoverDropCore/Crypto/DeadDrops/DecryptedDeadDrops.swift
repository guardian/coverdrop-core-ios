import Foundation

public struct DecryptedDeadDrops {
    var messages: [Message]
}

extension DecryptedDeadDrops {
    /// This decrypts a `VerifiedDeadDrops` data set with the supplied user secret key and journalist keys.
    /// - Parameters:
    ///   - userSecretKey: the user secret encryption key stored in the Ecrypted Storage
    ///   - journalistKey: a JournalistKeyData wrapper around the journalist public messaging keys
    ///   - verifiedDeadDropData: a VerifiedDeadDrops wrapper around a list of verified dead drops
    ///   - dateReceived: the date these messages where recieved, usually the current date.
    /// - Returns: A list of messages if there were any successful decryptions, or an empty list.
    static func decryptWithUserKey(userSecretKey: SecretEncryptionKey<User>, journalistData: JournalistData, verifiedDeadDropData: VerifiedDeadDrops, dateReceived: Date) async -> Set<Message> {
        var decryptedMessages: Set<Message> = []
        for deadDrop in verifiedDeadDropData.deadDrops {
            for message in deadDrop.data {
                async let maybeMessage = decryptJournalistToUserMessage(userSecretKey: userSecretKey, journalistData: journalistData, message: message, deadDropId: deadDrop.id, deadDropPublishedDate: deadDrop.publishedDate, dateReceived: dateReceived)
                if let message = await maybeMessage {
                    decryptedMessages.insert(message)
                }
            }
        }
        return decryptedMessages
    }

    /// This decrypts a `JournalistToUserMessage` ciphertext with the supplied user secret key and journalist keys.
    /// - Parameters:
    ///   - userSecretKey: the user secret encryption key stored in the Ecrypted Storage
    ///   - journalistKey: a JournalistKeyData wrapper around the journalist public messaging keys
    ///   - message: the ciphertext message as a `TwoPartyBox<PaddedCompressedString>` typealiased to `JournalistToUserMessage`
    ///   - deadDropId: the dead drop Id the message was found in
    ///   - dateReceived: the date these messages where recieved, usually the current date.
    /// - Returns: A Message if decryption was succesful, or nil
    private static func decryptJournalistToUserMessage(userSecretKey: SecretEncryptionKey<User>, journalistData: JournalistData, message: JournalistToUserMessage, deadDropId: Int, deadDropPublishedDate: Date, dateReceived: Date) -> Message? {
        var foundMessage: Message?

        guard let journalistMessagingKeys = PublicDataRepository.shared.verifiedPublicKeysData?.allMessageKeysForJournalistId(journalistId: journalistData.recipientId) else { return nil }
        // We try to decrypt the message with all the available keys for a journalist,

        for messageKey in journalistMessagingKeys {
            if let messageBytes: [UInt8] = try? TwoPartyBox<[UInt8]>.decrypt(senderPk: messageKey.key, recipientSk: userSecretKey, data: message) {
                if let message = DeadDropMessageParser.parseMessage(messageBytes: messageBytes, journalistData: journalistData, deadDropId: deadDropId, dateReceived: deadDropPublishedDate) {
                    foundMessage = message
                    break
                }
            }
        }
        return foundMessage
    }
}
