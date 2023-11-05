import Foundation

public enum SecretData {
    case lockedSecretData(lockedData: LockedSecretData)
    case unlockedSecretData(unlockedData: UnlockedSecretData)
}

public class LockedSecretData: Codable {
    init(encryptedData: [UInt8]) {
        self.encryptedData = encryptedData
    }

    public var encryptedData: [UInt8]
}

@MainActor
public class UnlockedSecretData: Codable, Equatable, ObservableObject {
    enum CodingKeys: CodingKey {
        case uuid, passphrase, messageMailbox, userKey, privateSendingQueueSecret
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(uuid, forKey: .uuid)
        try container.encode(passphrase, forKey: .passphrase)
        try container.encode(messageMailbox, forKey: .messageMailbox)
        try container.encode(userKey, forKey: .userKey)
        try container.encode(privateSendingQueueSecret, forKey: .privateSendingQueueSecret)
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        uuid = try container.decode(UUID.self, forKey: .uuid)
        passphrase = try container.decode(ValidPassword.self, forKey: .passphrase)
        messageMailbox = try container.decode([Message].self, forKey: .messageMailbox)
        userKey = try container.decode(EncryptionKeypair<User>.self, forKey: .userKey)
        privateSendingQueueSecret = try container.decode(PrivateSendingQueueSecret.self, forKey: .privateSendingQueueSecret)
    }

    public init(uuid: UUID = UUID(), passphrase: ValidPassword, messageMailbox: [Message], userKey: EncryptionKeypair<User>, privateSendingQueueSecret: PrivateSendingQueueSecret) {
        self.uuid = uuid
        self.passphrase = passphrase
        self.messageMailbox = messageMailbox
        self.userKey = userKey
        self.privateSendingQueueSecret = privateSendingQueueSecret
    }

    public static func == (lhs: UnlockedSecretData, rhs: UnlockedSecretData) -> Bool {
        return lhs.passphrase.password == rhs.passphrase.password &&
            lhs.messageMailbox == rhs.messageMailbox &&
            lhs.userKey.publicKey.key == rhs.userKey.publicKey.key &&
            lhs.userKey.secretKey.key == rhs.userKey.secretKey.key &&
            lhs.privateSendingQueueSecret == rhs.privateSendingQueueSecret
    }

    public var uuid: UUID = .init()
    public var passphrase: ValidPassword
    @Published public var messageMailbox: [Message]
    public var userKey: EncryptionKeypair<User>
    public var privateSendingQueueSecret: PrivateSendingQueueSecret

    public func addMessage(message: Message) {
        messageMailbox.append(message)
    }

    public func addMessages(messages: [Message]) {
        messages.forEach { message in
            messageMailbox.append(message)
        }
    }

    public func prependMessage(message: Message) {
        messageMailbox.insert(message, at: 0)
    }

    /// This gets the journalist or desks that the user has had converstations with
    /// This is used when we decrypt incoming dead drops so that we only try with keys for journalists
    /// we've been in converstations with.
    /// - Returns: A list of JournalistKeyData
    public func getMailboxRecipients() -> [JournalistKeyData] {
        let recipients = messageMailbox.compactMap { message in
            switch message {
                case .outboundMessage(message: let message):
                    return message.recipient
                case .incomingMessage(message: let messageType):
                    switch messageType {
                        case .textMessage(message: let message):
                            return message.sender
                        case .handoverMessage(message: let handover):
                            return UnlockedSecretData.getJournalistKeyDataForJournalistId(journalistId: handover.handoverTo)
                    }
            }
        }
        let uniqueRecipients = Set(recipients)
        return Array(uniqueRecipients)
    }

    public static func getJournalistKeyDataForJournalistId(journalistId: String) -> JournalistKeyData? {
        guard let publicKeyData = PublicDataRepository.shared.verifiedPublicKeysData,
              let journalistPublicKeyData = publicKeyData.allPublicKeysForJournalistId(journalistId: journalistId) else { return nil }

        let recentKeys: [JournalistMessagingPublicKey] = journalistPublicKeyData.compactMap { keyData in
            keyData.getMostRecentMessageKey()
        }

        guard let profileData = publicKeyData.journalistProfiles.first(where: { $0.id == journalistId }) else { return nil }

        return JournalistKeyData(recipientId: journalistId, displayName: profileData.displayName, isDesk: profileData.isDesk, messageKeys: recentKeys, recipientDescription: profileData.description, tag: RecipientTag(tag: profileData.tag.bytes))
    }
}

extension UnlockedSecretData: CustomStringConvertible {
    public var description: String {
        """
            uuid: \(uuid)
            passphrase: \(passphrase)
            messageMailbox: \(messageMailbox)
            userKey: \(userKey)
        """
    }
}

public struct JournalistKeyData: Hashable, Codable, Comparable {
    public static func < (lhs: JournalistKeyData, rhs: JournalistKeyData) -> Bool {
        return lhs.recipientId == rhs.recipientId &&
            lhs.tag == rhs.tag
    }

    public static func == (lhs: JournalistKeyData, rhs: JournalistKeyData) -> Bool {
        return lhs.recipientId == rhs.recipientId
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(recipientId)
    }

    public let recipientId: String
    public let displayName: String
    public let isDesk: Bool
    public func getMessageKey() -> JournalistMessagingPublicKey? {
        let sortedKeys = messageKeys.max { $0.notValidAfter > $1.notValidAfter }
        return sortedKeys ?? messageKeys.first
    }

    public let messageKeys: [JournalistMessagingPublicKey]
    public let recipientDescription: String
    public let tag: RecipientTag

    public init(recipientId: String, displayName: String, isDesk: Bool, messageKeys: [JournalistMessagingPublicKey], recipientDescription: String, tag: RecipientTag) {
        self.recipientId = recipientId
        self.displayName = displayName
        self.isDesk = isDesk
        self.messageKeys = messageKeys
        self.recipientDescription = recipientDescription
        self.tag = tag
    }

    public static func fromPublicKeysData(name: String, keysGroup: VerifiedJournalistPublicKeysGroup, profileData: JournalistProfile) -> JournalistKeyData {
        return JournalistKeyData(
            recipientId: name, displayName: profileData.displayName, isDesk: profileData.isDesk, messageKeys: keysGroup.msg, recipientDescription: profileData.description, tag: RecipientTag(tag: profileData.tag.bytes)
        )
    }
}
