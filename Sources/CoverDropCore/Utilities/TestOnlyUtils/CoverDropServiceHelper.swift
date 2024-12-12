import Foundation

enum CoverDropServiceHelperError: Error {
    case cannotGetTestJournalist
}

public enum CoverDropServiceHelper {
    public static func awaitCoverDropService() async throws {
        var ready = false
        repeat {
            try await Task.sleep(nanoseconds: UInt64(0.1))
            ready = await CoverDropServices.shared.isReady
        } while ready == false
    }

    #if DEBUG
        public static func removeBackgroundSendState(config: CoverDropConfig) async {
            if config.removeBackgroundSendStateOnStart {
                UserDefaults.standard.removeObject(forKey: "CoverDropBackgroundWorkLastSuccessfulRunTimestamp")
                UserDefaults.standard.removeObject(forKey: "CoverDropBackgroundWorkFailed")
            }
        }
    #endif
    public static func addTestStorage(config: CoverDropConfig) async throws {
        if config.startWithTestStorage {
            // If we are in UI_TEST_MODE, we want to initialise the storage with a known passphase
            // and set of user keys, so we can work with UI

            guard let testDefaultJournalist = PublicKeysHelper.shared.testDefaultJournalist else {
                throw CoverDropServiceHelperError.cannotGetTestJournalist
            }

            let passphrase = ValidPassword(password: "external jersey squeeze")
            let session = try await EncryptedStorage.createOrResetStorageWithPassphrase(passphrase: passphrase)

            // Set our test user keys
            let userSecretMessageKey = try PublicKeysHelper.shared.getTestUserMessageSecretKey()
            let userPublicMessageKey = try PublicKeysHelper.shared.getTestUserMessagePublicKey()
            let userKeyPair = EncryptionKeypair(publicKey: userPublicMessageKey, secretKey: userSecretMessageKey)
            let privateSendingQueueSecret = try PrivateSendingQueueSecret.fromSecureRandom()

            let encryptedMessage = try await UserToCoverNodeMessageData.createMessage(
                message: "Hey",
                messageRecipient: testDefaultJournalist,
                covernodeMessagePublicKey: PublicKeysHelper.shared.testKeys,
                userPublicKey: userKeyPair.publicKey
            )

            let hint = HintHmac(hint: PrivateSendingQueueHmac.hmac(
                secretKey: privateSendingQueueSecret.bytes,
                message: encryptedMessage.asBytes()
            ))

            var messages: Set<Message> = []
            if config.startWithTestMessages {
                let outboundMessage = await OutboundMessageData(
                    messageRecipient: testDefaultJournalist,
                    messageText: "Hey",
                    dateSent: Date(),
                    hint: hint
                )

                messages = [
                    .outboundMessage(message: outboundMessage),
                    .incomingMessage(message: .textMessage(message: IncomingMessageData(
                        sender: testDefaultJournalist,
                        messageText: "Hey",
                        dateReceived: Date()
                    )))
                ]
            }

            let data = UnlockedSecretData(
                messageMailbox: messages,
                userKey: userKeyPair,
                privateSendingQueueSecret: privateSendingQueueSecret
            )
            try await EncryptedStorage.updateStorageOnDisk(
                session: session,
                state: UnlockedSecretDataService(unlockedData: data)
            )
        }
    }
}
