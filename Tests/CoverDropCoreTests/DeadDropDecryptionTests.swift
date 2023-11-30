@testable import CoverDropCore
import Sodium
import XCTest

final class DeadDropDecryptionTests: XCTestCase {
    static var testerJournalistKeyData: JournalistKeyData? {
        guard let messageKey = PublicKeysHelper.shared.getTestJournalistMessageKey else {
            XCTFail("Failed to get key")
            return nil
        }
        return JournalistKeyData(recipientId: "tester_journalist",
                                 displayName: "tester",
                                 isDesk: false,
                                 messageKeys: [messageKey],
                                 recipientDescription: "This is a tester journalist", tag: RecipientTag(tag: [1, 2, 3, 4]))
    }

    func testDecryptMessageParsesTextMessage() async throws {
        let initalMessage = "This is a test message"
        let textMessage = try PaddedCompressedString.fromString(text: initalMessage).asUnencryptedBytes()

        let journalistKey = DeadDropDecryptionTests.testerJournalistKeyData

        if let journalistKey {
            let result = DeadDropMessageParser.parseMessage(messageBytes: textMessage, journalistKey: journalistKey, deadDropId: 1, dateReceived: Date())
            if case let .incomingMessage(message: incomingMessage) = result,
               case let .textMessage(message: messageText) = incomingMessage {
                XCTAssertEqual(messageText.messageText, initalMessage)
            } else {
                XCTFail("Failed to parse message")
            }
        } else {
            XCTFail("Failed to get Key")
        }
    }

    func testDecryptMessageParsesHandoverMessage() async throws {
        let journalistId = "static_test_journalist"
        let journalistIdBytes: [UInt8] = Array(journalistId.utf8)

        var handoverMessage = [DeadDropMessageParser.typeFlagHandover]

        handoverMessage.append(contentsOf: journalistIdBytes)

        let padding: [UInt8] = Array(repeating: 0x00, count: Constants.messagePaddingLen - handoverMessage.count)

        handoverMessage.append(contentsOf: padding)

        let journalistKey = DeadDropDecryptionTests.testerJournalistKeyData

        if let journalistKey {
            let result = DeadDropMessageParser.parseMessage(messageBytes: handoverMessage, journalistKey: journalistKey, deadDropId: 1, dateReceived: Date())
            if case let .incomingMessage(message: incomingMessage) = result,
               case let .handoverMessage(message: messageData) = incomingMessage {
                XCTAssertEqual(messageData.handoverTo, journalistId)
            } else {
                XCTFail("Failed to parse message")
            }
        } else {
            XCTFail("Failed to get Key")
        }
    }

    func testDecryptMessageFailsOnEmptyMessage() async throws {
        let handoverMessage: [UInt8] = []
        let journalistKey = DeadDropDecryptionTests.testerJournalistKeyData

        if let journalistKey {
            let result = DeadDropMessageParser.parseMessage(messageBytes: handoverMessage, journalistKey: journalistKey, deadDropId: 1, dateReceived: Date())
            XCTAssertNil(result)
        } else {
            XCTFail("Failed to get Key")
        }
    }
}
