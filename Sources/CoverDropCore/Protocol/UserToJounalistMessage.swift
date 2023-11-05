import Foundation

enum UserToJournalistMessageDataError: Error {
    case unableToExtractCoverNodeKeys
}

public struct UserToCoverNodeMessageData: Equatable, Encryptable {
    let userToJournalistMessage: AnonymousBox<UserToJournalistMessageData>
    let recipientTag: RecipientTag

    public func asUnencryptedBytes() -> [UInt8] {
        var buffer = recipientTag.tag
        buffer.append(contentsOf: userToJournalistMessage.asBytes())
        return buffer
    }

    public static func fromUnencryptedBytes(bytes: [UInt8]) throws -> UserToCoverNodeMessageData {
        let recipientTag = RecipientTag(tag: Array(bytes.prefix(Constants.recipientTagLen)))
        let userToJournalistMessage = AnonymousBox<UserToJournalistMessageData>.fromVecUnchecked(bytes: Array(bytes.suffix(Constants.userToJournalistEncryptedMessageLen)))
        return UserToCoverNodeMessageData(userToJournalistMessage: userToJournalistMessage, recipientTag: recipientTag)
    }

    public static func == (lhs: UserToCoverNodeMessageData, rhs: UserToCoverNodeMessageData) -> Bool {
        return lhs.recipientTag == rhs.recipientTag &&
            lhs.userToJournalistMessage.asBytes() == rhs.userToJournalistMessage.asBytes()
    }
}

public struct UserToJournalistMessageData: Equatable, Encryptable {
    let publicKey: PublicEncryptionKey<User>
    let paddedCompressedString: PaddedCompressedString

    public func asUnencryptedBytes() -> [UInt8] {
        var publicKeysBytes = publicKey.toBytes()
        let compressedStringBytes: [UInt8] = paddedCompressedString.value
        publicKeysBytes.append(contentsOf: compressedStringBytes)
        return publicKeysBytes
    }

    public static func fromUnencryptedBytes(bytes: [UInt8]) throws -> UserToJournalistMessageData {
        let publicKey = PublicEncryptionKey<User>(key: Array(bytes.prefix(Constants.x25519PublicKeyLen)))
        let plainTextPaddedCompresssedStringBytes = Array(bytes.suffix(Constants.messagePaddingLen))

        let plainTextPaddedCompresssedString = try PaddedCompressedString.fromUncheckedBytes(bytes: plainTextPaddedCompresssedStringBytes)
        return UserToJournalistMessageData(publicKey: publicKey, paddedCompressedString: plainTextPaddedCompresssedString)
    }
}

public enum UserToCoverNodeMessage {
    ///  This function creates the whole user to journalist message.
    ///  We first encrypt the inner message, then pass that payload into the encryption for the outer message
    /// See the [message protocol documentation for more details](https://github.com/guardian/coverdrop/blob/main/docs/protocol_messages.md#user-to-journalist-message)
    /// - Parameters:
    ///   - message: The plain text message composed by the user
    ///   - recipientPublicKey: The recipient journalist or desks Public Key
    ///   - covernodeMessagePublicKey: The public key for covernode
    ///   - userPublicKey: The current users public key, this is generated and stored in the Apps secret data storage
    /// - Returns: an AnonymousBox of byte array which is the ciphertext for the outer covernode message. This can be sent as is to the covernode service.
    public static func createMessage(message: String, recipientPublicKey: JournalistMessagingPublicKey, coverNodesToMostRecentMessagePublicKey: VerifiedPublicKeys, userPublicKey: PublicEncryptionKey<User>, tag: RecipientTag) async throws -> MultiAnonymousBox<UserToCoverNodeMessageData> {
        let innerMessage: AnonymousBox<UserToJournalistMessageData> = try await UserToCoverNodeMessage.encryptRealMessageFromUserToJournalistViaCovernode(recipentPublicKeyData: recipientPublicKey, userPublicKey: userPublicKey, message: message)
        let keys = coverNodesToMostRecentMessagePublicKey.mostRecentCoverNodeMessagingKeysFromAllHierarchies()
        let message = try UserToCoverNodeMessage.encryptRealMessageFromUserToCovernode(coverNodesToMostRecentMessagePublicKey: keys, userToJournalistMessage: innerMessage, recipientIdenitfierTag: tag)
        return message
    }

    /// creates the inner part of the covernode message See the [user to journalist message documentation for more details](https://github.com/guardian/coverdrop/blob/main/docs/protocol_messages.md#user-to-journalist-message)
    /// - Parameters:
    ///
    /// - message: The plain text message composed by the user
    ///   - recipientPublicKey: The recipient journalist or desks Public Key
    ///   - userPublicKey: The current users public key, this is generated and stored in the Apps secret data storage
    ///   - message: The plain text message composed by the user
    /// - Returns: an AnonymousBox of byte array which is the ciphertext for the inner  message.
    private static func encryptRealMessageFromUserToJournalistViaCovernode(recipentPublicKeyData: JournalistMessagingPublicKey, userPublicKey: PublicEncryptionKey<User>, message: String) async throws -> AnonymousBox<UserToJournalistMessageData> {
        // compress and pad the plaintext message
        let compressedMessage = try PaddedCompressedString.fromString(text: message)
        if compressedMessage.totalLength() != Constants.messagePaddingLen {
            throw PaddedCompressedStringError.paddedCompressedStringTooLong
        }
        // append the compressed the user public key
        let publicKeysBytes = PublicEncryptionKey<User>(key: userPublicKey.toBytes())

        let userToJournalistPlaintext = UserToJournalistMessageData(publicKey: publicKeysBytes, paddedCompressedString: compressedMessage)

        // create a PublicEncryptionKey instance from the recipient key bytes and
        // encrypt the padded compressed string and public key with Anonymous box
        let encrypted: AnonymousBox<UserToJournalistMessageData> = try AnonymousBox<UserToJournalistMessageData>.encrypt(recipientPk: recipentPublicKeyData.key, data: userToJournalistPlaintext)

        // prepend recipient_tag to make cover node message
        if encrypted.pkTagAndCiphertext.count != Constants.userToJournalistEncryptedMessageLen {
            throw EncryptionError.failedToEncrypt
        }

        return encrypted
    }

    /// The outer covernode message, See the [user to covernode message documentation for more details](https://github.com/guardian/coverdrop/blob/main/docs/protocol_messages.md#user-to-covernode-message)
    /// - Parameters:
    ///   - covernodeMessagePublicKey: The covernode message public key
    ///   - userToJournalistMessageWithTag: The user to journalist message encrypted as an `AnonymousBox`
    ///   - recipientIdenitfierTag:The first 4 bytes of a  SHA256 hash of the journalist Identifier (generally their name)
    /// - Returns: an AnonymousBox of byte array which is the ciphertext for the outer  message.
    private static func encryptRealMessageFromUserToCovernode(coverNodesToMostRecentMessagePublicKey: [CoverNodeIdentity: CoverNodeMessagingPublicKey], userToJournalistMessage: AnonymousBox<UserToJournalistMessageData>, recipientIdenitfierTag: RecipientTag) throws -> MultiAnonymousBox<UserToCoverNodeMessageData> {
        // append the covernode user to journalist message to the recipient Identifier Tag
        let serializedInnerCovernodeMessage = UserToCoverNodeMessageData(userToJournalistMessage: userToJournalistMessage, recipientTag: recipientIdenitfierTag)

        if serializedInnerCovernodeMessage.asUnencryptedBytes().count != (Constants.userToCovernodeMessageLen) {
            throw EncryptionError.failedToEncrypt
        }

        let coverNodeKeys = selectCovernodeKeys(coverNodeKeys: coverNodesToMostRecentMessagePublicKey)

        // encrypt the serializedInnerCovernodeMessage with the covernodeMessagePublicKey
        let encrypted: MultiAnonymousBox<UserToCoverNodeMessageData> = try MultiAnonymousBox<UserToCoverNodeMessageData>.encrypt(recipientPks: coverNodeKeys, data: serializedInnerCovernodeMessage)
        if encrypted.asBytes().count != (Constants.userToCovernodeEncryptedMessageLen) {
            throw EncryptionError.failedToEncrypt
        }

        return encrypted
    }

    /**
     * Selects the covernode encryption keys (exactly [COVERNODE_WRAPPING_KEY_COUNT] many) to
     * for encrypting the outer message. If the given keys are more than the output list size,
     * then the first ones are chosen. Otherwise, the first ones are repeated.
     */
    public static func selectCovernodeKeys(coverNodeKeys: [CoverNodeIdentity: CoverNodeMessagingPublicKey]) -> [PublicEncryptionKey<CoverNodeMessaging>] {
        if coverNodeKeys.isEmpty {
            return []
        }
        let coverNodeKeysData = coverNodeKeys.values.map { $0.key }
        return Array(1 ... Constants.covernodeWrappingKeyCount).compactMap { coverNodeKeysData[$0 % coverNodeKeysData.count] }
    }
}
