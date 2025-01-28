import Foundation

public enum SecretData {
    case lockedSecretData(lockedData: LockedSecretData)
    case unlockedSecretData(unlockedData: UnlockedSecretDataService)
}

public class LockedSecretData: Codable {}

public class UnlockedSecretData: Codable, Equatable {
    public var uuid: UUID = .init()
    public var messageMailbox: Set<Message>
    public var userKey: EncryptionKeypair<User>
    public var privateSendingQueueSecret: PrivateSendingQueueSecret

    enum CodingKeys: CodingKey {
        case uuid, messageMailbox, userKey, privateSendingQueueSecret
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(uuid, forKey: .uuid)
        try container.encode(messageMailbox, forKey: .messageMailbox)
        try container.encode(userKey, forKey: .userKey)
        try container.encode(privateSendingQueueSecret, forKey: .privateSendingQueueSecret)
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        uuid = try container.decode(UUID.self, forKey: .uuid)
        messageMailbox = try container.decode(Set<Message>.self, forKey: .messageMailbox)
        userKey = try container.decode(EncryptionKeypair<User>.self, forKey: .userKey)
        privateSendingQueueSecret = try container.decode(
            PrivateSendingQueueSecret.self,
            forKey: .privateSendingQueueSecret
        )
    }

    public init(
        uuid: UUID = UUID(),
        messageMailbox: Set<Message>,
        userKey: EncryptionKeypair<User>,
        privateSendingQueueSecret: PrivateSendingQueueSecret
    ) {
        self.uuid = uuid
        self.messageMailbox = messageMailbox
        self.userKey = userKey
        self.privateSendingQueueSecret = privateSendingQueueSecret
    }

    public static func == (lhs: UnlockedSecretData, rhs: UnlockedSecretData) -> Bool {
        return lhs.messageMailbox == rhs.messageMailbox &&
            lhs.userKey.publicKey.key == rhs.userKey.publicKey.key &&
            lhs.userKey.secretKey.key == rhs.userKey.secretKey.key &&
            lhs.privateSendingQueueSecret == rhs.privateSendingQueueSecret
    }
}

@MainActor
public class UnlockedSecretDataService: ObservableObject {
    init(unlockedData: UnlockedSecretData) {
        self.unlockedData = unlockedData
    }

    @Published public var unlockedData: UnlockedSecretData

    public func addMessage(message: Message) async throws {
        unlockedData.messageMailbox.insert(message)
        try await storeData()
    }

    public func addMessages(messages: Set<Message>) async throws {
        unlockedData.messageMailbox.formUnion(messages)
        try await storeData()
    }

    public func storeData() async throws {
        try await SecretDataRepository.shared.storeData(unlockedData: self)
    }

    /// This gets the journalist or desks that the user has had converstations with
    /// This is used when we decrypt incoming dead drops so that we only try with keys for journalists
    /// we've been in converstations with.
    /// - Returns: A list of JournalistKeyData
    public func getMailboxRecipients(publicKeyData: VerifiedPublicKeys) async -> [JournalistData] {
        let recipients = unlockedData.messageMailbox.compactMap { message in
            switch message {
            case let .outboundMessage(message: message):
                return message.recipient
            case let .incomingMessage(message: messageType):
                switch messageType {
                case let .textMessage(message: message):
                    return message.sender
                case let .handoverMessage(message: handover):
                    return UnlockedSecretDataService.getJournalistKeyDataForJournalistId(
                        journalistId: handover.handoverTo,
                        publicKeyData: publicKeyData
                    )
                }
            }
        }
        let uniqueRecipients = Set(recipients)
        return Array(uniqueRecipients)
    }

    public static func createNewEmpty() throws -> UnlockedSecretDataService {
        let userKeyPair: EncryptionKeypair<User> = try EncryptionKeypair<User>.generateEncryptionKeypair()
        let privateSendingQueueSecret = try PrivateSendingQueueSecret.fromSecureRandom()
        return UnlockedSecretDataService(unlockedData: UnlockedSecretData(
            messageMailbox: [],
            userKey: userKeyPair,
            privateSendingQueueSecret: privateSendingQueueSecret
        ))
    }

    public static func getJournalistKeyDataForJournalistId(journalistId: String,
                                                           publicKeyData: VerifiedPublicKeys) -> JournalistData? {
        guard let profileData = publicKeyData.journalistProfiles.first(where: { $0.id == journalistId }) else { return nil }

        return JournalistData(
            recipientId: journalistId,
            displayName: profileData.displayName,
            isDesk: profileData.isDesk,
            recipientDescription: profileData.description,
            tag: RecipientTag(tag: profileData.tag.bytes),
            visibility: (profileData.status == .visible) ? JournalistVisibility.visible : JournalistVisibility.hidden
        )
    }
}
