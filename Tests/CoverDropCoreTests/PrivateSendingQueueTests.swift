@testable import CoverDropCore
import Sodium
import XCTest

final class PrivateSendingQueueTests: XCTestCase {
    let secret = PrivateSendingQueueSecret(bytes: "secret__secret__".asBytes())
    func message(message: String) async throws -> MultiAnonymousBox<UserToCoverNodeMessageData> {
        let userKeyPair: EncryptionKeypair<User> = try EncryptionKeypair<User>.generateEncryptionKeypair()

        let encryptedMessage = try await UserToCoverNodeMessage.createMessage(message: message,
                                                                              recipientPublicKey: PublicKeysHelper.shared.getTestJournalistMessageKey!,
                                                                              coverNodesToMostRecentMessagePublicKey: PublicKeysHelper.shared.testKeys,
                                                                              userPublicKey: userKeyPair.publicKey, tag: RecipientTag(tag: [2, 3, 3, 3]))
        return encryptedMessage
    }

    func message1() async throws -> MultiAnonymousBox<UserToCoverNodeMessageData> {
        return try await message(message: "message 1")
    }

    func message2() async throws -> MultiAnonymousBox<UserToCoverNodeMessageData> {
        return try await message(message: "message 2")
    }

    func message3() async throws -> MultiAnonymousBox<UserToCoverNodeMessageData> {
        return try await message(message: "message 3")
    }

    func emptyCoverdropQueue() throws -> PrivateSendingQueue {
        return try PrivateSendingQueue(totalQueueSize: PrivateSendingQueueConfiguration.default.totalQueueSize,
                                       messageSize: PrivateSendingQueueConfiguration.default.messageSize)
    }

    func testEnqueueWhenAddingMessageThenFillLevelIncreases() async throws {
        var queue = try emptyCoverdropQueue()
        XCTAssertTrue(queue.getFillLevel(secret: secret!) == 0)

        try await queue.enqueue(secret: secret!, message: message1())
        XCTAssertTrue(queue.getFillLevel(secret: secret!) == 1)

        try await queue.enqueue(secret: secret!, message: message2())
        XCTAssertTrue(queue.getFillLevel(secret: secret!) == 2)
    }

    func testEnqueueWhenCheckingFillLevelWithWrongSecretThenReturnsEmpty() async throws {
        let wrongSecret = PrivateSendingQueueSecret(bytes: "__terces__terces".asBytes())

        var queue = try emptyCoverdropQueue()
        XCTAssertTrue(queue.getFillLevel(secret: secret!) == 0)

        try await queue.enqueue(secret: secret!, message: message1())
        XCTAssertTrue(queue.getFillLevel(secret: wrongSecret!) == 0)

        try await queue.enqueue(secret: secret!, message: message2())
        XCTAssertTrue(queue.getFillLevel(secret: wrongSecret!) == 0)
    }

    func testEnqueueWhenAddingMessagesBeyondCapacityThenSpaceThenThrows() async throws {
        let message1 = try await message1()
        var queue = try emptyCoverdropQueue()
        for _ in 0 ..< PrivateSendingQueueConfiguration.default.totalQueueSize {
            try queue.enqueue(secret: secret!, message: message1)
        }

        XCTAssertThrowsError(try queue.enqueue(secret: secret!, message: message1)) { error in
            XCTAssertEqual(error as! PrivateSendingQueueError, PrivateSendingQueueError.queueIsFull)
        }
    }

    func testEnqueueWhenAddingMessageWithDifferentSecretThenOthersOverwritten() async throws {
        let message1 = try await message1()
        let message2 = try await message2()
        let message3 = try await message3()

        let differentSecret = PrivateSendingQueueSecret(bytes: "__terces__terces".asBytes())

        var queue = try emptyCoverdropQueue()
        try queue.enqueue(secret: secret!, message: message1)
        try queue.enqueue(secret: secret!, message: message2)
        try queue.enqueue(secret: differentSecret!, message: message3)

        // we would have otherwise expected message1 due to the FIFO nature of the queue
        XCTAssertEqual(try queue.dequeue(), message3)
    }

    func testDequeueWhenAddedMessagesThenPoppedInOrder() async throws {
        let message1 = try await message1()
        let message2 = try await message2()

        var queue = try emptyCoverdropQueue()
        try queue.enqueue(secret: secret!, message: message1)
        try queue.enqueue(secret: secret!, message: message2)

        XCTAssertEqual(try queue.dequeue(), message1)
        XCTAssertEqual(try queue.dequeue(), message2)
    }

    func testDequeueWhenPoppingMoreThanRealMessagesThenCoverMessagesReturned() async throws {
        let message1 = try await message1()
        let message2 = try await message2()

        var queue = try emptyCoverdropQueue()
        try queue.enqueue(secret: secret!, message: message1)
        try queue.enqueue(secret: secret!, message: message2)

        XCTAssertEqual(try queue.dequeue(), message1)
        XCTAssertEqual(try queue.dequeue(), message2)

        _ = try queue.dequeue()

        XCTAssertNotEqual(try queue.dequeue(), message1)
        XCTAssertNotEqual(try queue.dequeue(), message2)
    }

    func testFromBytesWhenSerdeEmptyThenDeserializesSuccessfully() throws {
        let original = try emptyCoverdropQueue()
        let serialized = try original.serialize()
        let new = try PrivateSendingQueue.fromBytes(bytes: serialized)
        XCTAssert(original == new)
    }

    func testFromBytesWhenSerdeWithMessagesThenDeserializesSuccessfully() async throws {
        let message1 = try await message1()
        let message2 = try await message2()

        var original = try emptyCoverdropQueue()
        try original.enqueue(secret: secret!, message: message1)
        try original.enqueue(secret: secret!, message: message2)

        let serialized = try original.serialize()

        var copy = try PrivateSendingQueue.fromBytes(bytes: serialized)

        let fillLevel = copy.getFillLevel(secret: secret!)
        XCTAssertEqual(fillLevel, 2)

        let actualMessage1 = try copy.dequeue()
        XCTAssertEqual(actualMessage1, message1)

        let actualMessage2 = try copy.dequeue()
        XCTAssertEqual(actualMessage2, message2)

        try original.dequeue() // message 1
        try original.dequeue() // message 2
        let originalCover1 = try original.dequeue()
        let actualCover1 = try copy.dequeue()
        XCTAssertEqual(originalCover1, actualCover1)
    }

    func testCanCheckMessageStillInQueue() async throws {
        let message1 = try await message1()
        let message2 = try await message2()

        var original = try emptyCoverdropQueue()
        let hint1 = try original.enqueue(secret: secret!, message: message1)
        let hint2 = try original.enqueue(secret: secret!, message: message2)

        let isInQueue = original.isMessageStillInQueue(hint: hint1)

        XCTAssertTrue(isInQueue)

        try original.dequeue() // message 1
        try original.dequeue() // message 2

        let isStillInQueue = original.isMessageStillInQueue(hint: hint1)

        XCTAssertFalse(isStillInQueue)
    }
}
