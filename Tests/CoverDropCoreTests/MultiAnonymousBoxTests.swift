@testable import CoverDropCore
import Sodium
import XCTest

// swiftlint:disable force_try identifier_name

final class MultiAnonymousBoxTests: XCTestCase {
    func testEncryptDecrypt_whenSameKeys_thenActualMatchesOriginal() throws {
        let recipientKeypair: EncryptionKeypair<CoverNodeMessaging> = try EncryptionKeypair<CoverNodeMessaging>.generateEncryptionKeypair()
        let originalMessage = "안녕하세요"

        let encrypted: MultiAnonymousBox<String> = try! MultiAnonymousBox<String>.encrypt(recipientPks: [recipientKeypair.publicKey], data: originalMessage)

        let decrypted = try! MultiAnonymousBox<String>.decrypt(recipientPk: recipientKeypair.publicKey, recipientSk: recipientKeypair.secretKey, data: encrypted, numRecipients: 1)

        XCTAssertEqual(originalMessage, decrypted)
    }

    func testEncryptDecrypt_whenFlippingBitInCiphertext_thenDecryptFails() throws {
        let recipientKeypair: EncryptionKeypair<CoverNodeMessaging> = try EncryptionKeypair<CoverNodeMessaging>.generateEncryptionKeypair()
        let originalMessage = "안녕하세요"

        var encrypted: MultiAnonymousBox<String> = try! MultiAnonymousBox<String>.encrypt(recipientPks: [recipientKeypair.publicKey], data: originalMessage)

        encrypted.bytes[0] = encrypted.bytes[0] ^ 0x01

        // this fails and throws
        XCTAssertThrowsError(try MultiAnonymousBox<String>.decrypt(recipientPk: recipientKeypair.publicKey, recipientSk: recipientKeypair.secretKey, data: encrypted, numRecipients: 1)) { error in
            XCTAssertEqual(error as! MultiAnonymousBoxError, MultiAnonymousBoxError.decryptWithSecretBoxFailed)
        }
    }

    func testEncryptDecrypt_whenMultipleRecipients_thenAllDecryptCorrectly() throws {
        let numRecipients = 2
        let recipientKeypairs: [EncryptionKeypair<CoverNodeMessaging>] = try Array(1 ... numRecipients).compactMap { _ in
            try EncryptionKeypair<CoverNodeMessaging>.generateEncryptionKeypair()
        }
        let originalMessage = "안녕하세요"

        let encrypted: MultiAnonymousBox<String> = try! MultiAnonymousBox<String>.encrypt(recipientPks: recipientKeypairs.map { $0.publicKey }, data: originalMessage)

        for recipient in recipientKeypairs {
            let decrypted = try MultiAnonymousBox<String>.decrypt(recipientPk: recipient.publicKey, recipientSk: recipient.secretKey, data: encrypted, numRecipients: numRecipients)
            XCTAssertEqual(originalMessage, decrypted)
        }
    }
}
