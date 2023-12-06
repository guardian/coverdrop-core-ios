import CryptoKit
import Foundation

public enum CoverDropServiceHelper {
    public static func awaitCoverDropService() async throws {
        var ready = false
        repeat {
            try await Task.sleep(nanoseconds: UInt64(0.1))
            ready = await CoverDropServices.shared.isReady
        } while ready == false
    }

    public static func addTestStorage() async throws {
        if ApplicationConfig.config.startWithTestStorage {
            // If we are in UI_TEST_MODE, we want to initialise the storage with a known passphase
            // and set of user keys, so we can work with UI
            let passphrase = ValidPassword(password: "external jersey squeeze luckiness")
            let userSecretMessageKey = try PublicKeysHelper.shared.getTestUserMessageSecretKey()
            let userPublicMessageKey = try PublicKeysHelper.shared.getTestUserMessagePublicKey()
            let userKeyPair = EncryptionKeypair(publicKey: userPublicMessageKey, secretKey: userSecretMessageKey)

            let storage = try await EncryptedStorage.createNewStorageWithPassphrase(passphrase: passphrase, withSecureEnclave: SecureEnclave.isAvailable, userKeyPair: userKeyPair)

            if ApplicationConfig.config.startWithTestMessages {
                if let testDefaultJournalist = PublicKeysHelper.shared.testDefaultJournalist {
                    let messages: Set<Message> = await [
                        .outboundMessage(message: OutboundMessageData(recipient: testDefaultJournalist, messageText: "Hey", dateSent: Date())),
                        .incomingMessage(message: .textMessage(message: IncomingMessageData(sender: testDefaultJournalist, messageText: "Hey", dateReceived: Date())))
                    ]
                    let newStateWithMessages = await UnlockedSecretData(passphrase: passphrase, messageMailbox: messages, userKey: userKeyPair, privateSendingQueueSecret: storage.privateSendingQueueSecret)
                    let key = try await SecureEnclavePrivateKey.loadKey(name: EncryptedStorage.fileName)
                    try await EncryptedStorage.updateStorageOnDisk(storage: storage, passphrase: passphrase, newState: newStateWithMessages, withSecureEnclave: SecureEnclave.isAvailable, secureEnclaveKey: key)
                }
            }
        }
    }
}
