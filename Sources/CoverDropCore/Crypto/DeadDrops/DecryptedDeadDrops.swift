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
    static func decryptWithUserKey(userSecretKey: SecretEncryptionKey<User>, journalistKey: JournalistKeyData, verifiedDeadDropData: VerifiedDeadDrops, dateReceived: Date) -> [Message] {
        let decryptedMessages: [[Message]] = verifiedDeadDropData.deadDrops.compactMap { deadDrop in
            deadDrop.data.compactMap { message in
                decryptJournalistToUserMessage(userSecretKey: userSecretKey, journalistKey: journalistKey, message: message, deadDropId: deadDrop.id, deadDropPublishedDate: deadDrop.publishedDate, dateReceived: dateReceived)
            }
        }
        return Array(decryptedMessages.joined())
    }

    /// This decrypts a `JournalistToUserMessage` ciphertext with the supplied user secret key and journalist keys.
    /// - Parameters:
    ///   - userSecretKey: the user secret encryption key stored in the Ecrypted Storage
    ///   - journalistKey: a JournalistKeyData wrapper around the journalist public messaging keys
    ///   - message: the ciphertext message as a `TwoPartyBox<PaddedCompressedString>` typealiased to `JournalistToUserMessage`
    ///   - deadDropId: the dead drop Id the message was found in
    ///   - dateReceived: the date these messages where recieved, usually the current date.
    /// - Returns: A Message if decryption was succesful, or nil
    private static func decryptJournalistToUserMessage(userSecretKey: SecretEncryptionKey<User>, journalistKey: JournalistKeyData, message: JournalistToUserMessage, deadDropId: Int, deadDropPublishedDate _: Date, dateReceived: Date) -> Message? {
        var foundMessage: Message?
        // We try to decrypt the message with all the available keys for a journalist,
        for messageKey in journalistKey.messageKeys {
            if let maybePaddedMessage: PaddedCompressedString? = try? TwoPartyBox<PaddedCompressedString>.decrypt(senderPk: messageKey.key, recipientSk: userSecretKey, data: message),
               let paddedMessage = maybePaddedMessage,
               let messageText = try? paddedMessage.toString()
            {
                foundMessage = .incomingMessage(message: IncomingMessageData(sender: journalistKey, messageText: messageText, dateReceived: dateReceived, deadDropId: deadDropId))
                break
            }
            continue
        }
        return foundMessage
    }
}
