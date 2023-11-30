import Foundation

/// This helper is used to generate a mock user message inbox for the purpose of previewing the UI in xcode
/// It is located here because our tests are defined across multiple packages, and CoverDropCore is a common dependency of them all
@MainActor public enum MessageHelper {
    public static func addMessagesToInbox() throws -> SecretData {
        let passphrase = ValidPassword(password: "external jersey squeeze luckiness collector")

        let journalistMessageKey = PublicKeysHelper.shared.getTestJournalistMessageKey

        let recipient = PublicKeysHelper.shared.testDefaultJournalist

        let otherRecipient = PublicKeysHelper.shared.getTestDesk
        // setup the message mailbox to be empty
        var messages: [Message] = []

        let userKeyPair: EncryptionKeypair<User> = try EncryptionKeypair<User>.generateEncryptionKeypair()
        let privateSendingQueueSecret = try PrivateSendingQueueSecret.fromSecureRandom()

        if let recipientUnwrapped = recipient,
           let otherRecipientUnwrapped = otherRecipient {
            let nonExpiredMessage = Message.outboundMessage(message: OutboundMessageData(recipient: recipientUnwrapped, messageText: "hey \(recipientUnwrapped.displayName)", dateSent: Date(timeIntervalSinceNow: TimeInterval(1 - (60 * 60 * 24 * 2))), hint: HintHmac(hint: PrivateSendingQueueHmac.hmac(secretKey: privateSendingQueueSecret.bytes, message: "hey".asBytes()))))

            let realMessage = Message.outboundMessage(message: OutboundMessageData(recipient: recipientUnwrapped, messageText: "hey outbound \(recipientUnwrapped.displayName)", dateSent: Date(timeIntervalSinceNow: TimeInterval(1 - (60 * 60 * 24 * 12))), hint: HintHmac(hint: PrivateSendingQueueHmac.hmac(secretKey: privateSendingQueueSecret.bytes, message: "hey".asBytes()))))

            let realReplyMessage = Message.incomingMessage(message: .textMessage(message: IncomingMessageData(sender: recipientUnwrapped, messageText: "hey user, from: \(recipientUnwrapped.displayName)", dateReceived: Date())))

            let inactiveMessage1 = Message.outboundMessage(message: OutboundMessageData(recipient: otherRecipientUnwrapped, messageText: "hey \(otherRecipientUnwrapped.displayName)", dateSent: Date(timeIntervalSinceNow: TimeInterval(1 - (60 * 60 * 24 * 13))), hint: HintHmac(hint: PrivateSendingQueueHmac.hmac(secretKey: privateSendingQueueSecret.bytes, message: "hey".asBytes()))))

            let inactiveMessage2 = Message.incomingMessage(message: .textMessage(message: IncomingMessageData(sender: otherRecipientUnwrapped, messageText: "hey user from \(otherRecipientUnwrapped.displayName)", dateReceived: Date(timeIntervalSinceNow: TimeInterval(1 - (60 * 60 * 24 * 13))))))
            // add a message to the inbox
            messages.append(realMessage)
            messages.append(nonExpiredMessage)
            messages.append(realReplyMessage)
            messages.append(inactiveMessage1)
            messages.append(inactiveMessage2)
        }

        return .unlockedSecretData(unlockedData: UnlockedSecretData(passphrase: passphrase, messageMailbox: messages, userKey: userKeyPair, privateSendingQueueSecret: privateSendingQueueSecret))
    }

    public static func loadMessagesFromDeadDrop() throws -> SecretData {
        let passphrase = ValidPassword(password: "external jersey squeeze luckiness collector")

        let journalistMessageKey = PublicKeysHelper.shared.testDefaultJournalist
        let publicKeys = PublicKeysHelper.shared.testKeys

        let recipient = PublicKeysHelper.shared.testDefaultJournalist

        let otherRecipient = PublicKeysHelper.shared.getTestDesk
        // setup the message mailbox to be empty
        var messages: [Message] = []

        let userMessageSecretKey = try PublicKeysHelper.shared.getTestUserMessageSecretKey()
        let userMessagePublicKey = try PublicKeysHelper.shared.getTestUserMessagePublicKey()
        let userKeyPair: EncryptionKeypair<User> = EncryptionKeypair(publicKey: userMessagePublicKey, secretKey: userMessageSecretKey)
        let privateSendingQueueSecret = try PrivateSendingQueueSecret.fromSecureRandom()

        let deadDropData = try DeadDropDataHelper.shared.readLocalDataFile()
        let verifiedDeadDrops = VerifiedDeadDrops.fromAllDeadDropData(deadDrops: deadDropData, verifiedKeys: publicKeys)
        let secretDataRepository = SecretDataRepository.shared
        let publicDataRepository = PublicDataRepository.shared

        let userMessages: [[Message]] = try [journalistMessageKey].compactMap { keys in
            let messages: [Message]? = try keys.flatMap { key in
                try DecryptedDeadDrops.decryptWithUserKey(userSecretKey: userMessageSecretKey, journalistKey: key, verifiedDeadDropData: verifiedDeadDrops, dateReceived: PublicKeysHelper.readLocalGeneratedAtFile()!)
            }
            return messages
        }

        let flattenedMessage = userMessages.flatMap { $0 }

        return .unlockedSecretData(unlockedData: UnlockedSecretData(passphrase: passphrase, messageMailbox: flattenedMessage, userKey: userKeyPair, privateSendingQueueSecret: privateSendingQueueSecret))
    }
}
