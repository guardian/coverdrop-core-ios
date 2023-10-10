@testable import CoverDropCore
import Sodium
import XCTest

// swiftlint:disable force_try identifier_name

final class AnonymouseBoxTests: XCTestCase {
    func testRoundTrip() throws {
        let input = "안녕하세요"
        let recipientKeypair: EncryptionKeypair<JournalistMessaging> = try EncryptionKeypair<JournalistMessaging>.generateEncryptionKeypair()

        let encrypted: AnonymousBox<String> = try! AnonymousBox<String>.encrypt(recipientPk: recipientKeypair.publicKey, data: input)
        let decrypted = try! AnonymousBox<String>.decrypt(myPk: recipientKeypair.publicKey, mySk: recipientKeypair.secretKey, data: encrypted)

        XCTAssertEqual(input, decrypted)
    }

    func testRoundTripWithUInt8() throws {
        let input: [UInt8] = [52, 32, 25, 27]
        let recipientKeypair: EncryptionKeypair<JournalistMessaging> = try EncryptionKeypair<JournalistMessaging>.generateEncryptionKeypair()

        let encrypted: AnonymousBox<[UInt8]> = try! AnonymousBox<[UInt8]>.encrypt(recipientPk: recipientKeypair.publicKey, data: input)
        let decrypted = try! AnonymousBox<[UInt8]>.decrypt(myPk: recipientKeypair.publicKey, mySk: recipientKeypair.secretKey, data: encrypted)

        XCTAssertEqual(input, decrypted)
    }

    func testWorksViaUnchecked() throws {
        let input = "안녕하세요"
        let recipientKeypair: EncryptionKeypair<JournalistMessaging> = try EncryptionKeypair<JournalistMessaging>.generateEncryptionKeypair()

        let encrypted: AnonymousBox<String> = try! AnonymousBox<String>.encrypt(recipientPk: recipientKeypair.publicKey, data: input)

        let raw_bytes = encrypted.pkTagAndCiphertext

        let from_bytes = AnonymousBox<String>.fromVecUnchecked(bytes: raw_bytes)
        let decrypted: String = try! AnonymousBox<String>.decrypt(myPk: recipientKeypair.publicKey, mySk: recipientKeypair.secretKey, data: from_bytes)

        XCTAssertEqual(input, decrypted)
    }

    func testFailsWhenUsingDifferentKey() throws {
        let input = "안녕하세요"

        let intendedRecipientKeypair: EncryptionKeypair<JournalistMessaging> = try EncryptionKeypair<JournalistMessaging>.generateEncryptionKeypair()
        let otherRecipientKeypair: EncryptionKeypair<JournalistMessaging> = try EncryptionKeypair<JournalistMessaging>.generateEncryptionKeypair()

        let encrypted: AnonymousBox<String> = try! AnonymousBox<String>.encrypt(recipientPk: intendedRecipientKeypair.publicKey, data: input)

        XCTAssertThrowsError(try AnonymousBox<String>.decrypt(myPk: otherRecipientKeypair.publicKey, mySk: otherRecipientKeypair.secretKey, data: encrypted)) { error in
            XCTAssertEqual(error as! EncryptionError, EncryptionError.failedToDecrypt)
        }
    }
}
