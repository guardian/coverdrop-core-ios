@testable import CoverDropCore
import Sodium
import XCTest

final class PrivateSendingQueueRepositoryTests: XCTestCase {
    static let config = PrivateSendingQueueConfiguration.default
    private let testingSecret = PrivateSendingQueueTests().secret!

    override func setUp() {
        do {
            let fileURL = try PrivateSendingQueueDataStore.privateSendingQueueStorageFileURL.path
            if FileManager.default.fileExists(atPath: fileURL) {
                try FileManager.default.removeItem(atPath: fileURL)
            }
        } catch {
            XCTFail("Failed to setup test")
        }
    }

    func testRoundTrip() async throws {
        let secret = PrivateSendingQueueSecret(bytes: "secret__secret__".asBytes())

        let userKeyPair: EncryptionKeypair<User> = try EncryptionKeypair<User>.generateEncryptionKeypair()
        let encryptedMessage = try await UserToCoverNodeMessage.createMessage(message: "message 1",
                                                                              recipientPublicKey: PublicKeysHelper.shared.getTestJournalistMessageKey!,
                                                                              coverNodesToMostRecentMessagePublicKey: PublicKeysHelper.shared.testKeys,
                                                                              userPublicKey: userKeyPair.publicKey, tag: RecipientTag(tag: [1, 2, 3, 4]))

        let queue = try PrivateSendingQueue(totalQueueSize: PrivateSendingQueueRepositoryTests.config.totalQueueSize,
                                            messageSize: PrivateSendingQueueRepositoryTests.config.messageSize)

        let testableRepo = try await PrivateSendingQueueRepository.createTestableInstance(queue: queue)
        try await testableRepo.start()

        let initialQueue = await testableRepo.testableQueue

        let hmac = try await testableRepo.enqueue(secret: secret!,
                                                  message: encryptedMessage)

        let newQueueState = await testableRepo.testableQueue

        XCTAssert(initialQueue != newQueueState)
    }

    func testAddingTwoMessagesWithinCapacity() async throws {
        let queue = try PrivateSendingQueue(totalQueueSize: PrivateSendingQueueRepositoryTests.config.totalQueueSize,
                                            messageSize: PrivateSendingQueueRepositoryTests.config.messageSize)

        let testableRepo = try await PrivateSendingQueueRepository.createTestableInstance(queue: queue)
        try await testableRepo.start()

        let message = try await PrivateSendingQueueTests().message1()

        // GIVEN a queue with 2 empty slots
        for _ in 0 ..< (PrivateSendingQueueConfiguration.default.totalQueueSize - 2) {
            try await testableRepo.enqueue(secret: testingSecret, message: message)
        }

        // WHEN attempting to add 2 messages
        let errorsCount = try await addTwoMessagesConcurrentlyReturningErrorCount(to: testableRepo)

        // THEN 0 errors should be thrown
        XCTAssert(errorsCount == 0)
    }

    func testAddingOneMessageBeyondCapacity() async throws {
        let queue = try PrivateSendingQueue(totalQueueSize: PrivateSendingQueueRepositoryTests.config.totalQueueSize,
                                            messageSize: PrivateSendingQueueRepositoryTests.config.messageSize)

        let testableRepo = try await PrivateSendingQueueRepository.createTestableInstance(queue: queue)
        try await testableRepo.start()

        let message = try await PrivateSendingQueueTests().message1()

        // GIVEN a queue with 1 empty slots
        for _ in 0 ..< (PrivateSendingQueueConfiguration.default.totalQueueSize - 1) {
            try await testableRepo.enqueue(secret: PrivateSendingQueueTests().secret!, message: message)
        }

        // WHEN attempting to add 2 messages
        let errorsCount = try await addTwoMessagesConcurrentlyReturningErrorCount(to: testableRepo)

        // THEN 1 errors should be thrown
        XCTAssert(errorsCount == 1)
    }

    func testAddingTwoMessagesBeyondCapacity() async throws {
        let queue = try PrivateSendingQueue(totalQueueSize: PrivateSendingQueueRepositoryTests.config.totalQueueSize,
                                            messageSize: PrivateSendingQueueRepositoryTests.config.messageSize)

        let testableRepo = try await PrivateSendingQueueRepository.createTestableInstance(queue: queue)
        try await testableRepo.start()

        let message = try await PrivateSendingQueueTests().message1()

        // GIVEN a queue with 0 empty slots
        for _ in 0 ..< PrivateSendingQueueConfiguration.default.totalQueueSize {
            try await testableRepo.enqueue(secret: testingSecret, message: message)
        }

        // WHEN attempting to add 2 messages
        let errorsCount = try await addTwoMessagesConcurrentlyReturningErrorCount(to: testableRepo)

        // THEN 2 errors should be thrown
        XCTAssert(errorsCount == 2)
    }

    @discardableResult
    private func addTwoMessagesConcurrentlyReturningErrorCount(to repository: PrivateSendingQueueRepository) async throws -> Int {
        let taskPriorities: [TaskPriority] = [.low, .high, .medium, .utility, .background, .userInitiated]

        let message = try await PrivateSendingQueueTests().message1()

        let addTask = Task.detached(priority: taskPriorities.randomElement()) {
            try await repository.enqueue(secret: self.testingSecret, message: message)
        }

        let addTask2 = Task.detached(priority: taskPriorities.randomElement()) {
            try await repository.enqueue(secret: self.testingSecret, message: message)
        }

        var errorsCount = 0

        do {
            try await addTask.result.get()
        } catch {
            errorsCount += 1
        }

        do {
            try await addTask2.result.get()
        } catch {
            errorsCount += 1
        }

        return errorsCount
    }

    func testEnqueued() async throws {
        // GIVEN an initialized empty queue
        let testableDataStore = PrivateSendingQueueDataStore()
        let sut = try await PrivateSendingQueueRepository.createTestableInstance(dataStore: testableDataStore)
        try await sut.start()

        // THEN the queue should be empty initially
        let fillLevel = await sut.testableQueue?.getFillLevel(secret: testingSecret)
        XCTAssert(fillLevel == 0)

        // WHEN two messages are added
        try await addTwoMessagesConcurrentlyReturningErrorCount(to: sut)

        // THEN the repo's queue should have 2 messages in memory
        let filled = await sut.testableQueue
        let fillLevel2 = filled?.getFillLevel(secret: testingSecret)
        XCTAssert(fillLevel2 == 2)

        // AND the queue in memory should be the same as the queue in the datastore
        let stored = try await testableDataStore.loadQueue()
        XCTAssert(filled == stored)
    }

    func testDequeue() async throws {
        // GIVEN an initialized queue with 2 messages
        let testableDataStore = PrivateSendingQueueDataStore()
        let sut = try await PrivateSendingQueueRepository.createTestableInstance(dataStore: testableDataStore)
        try await sut.start()
        try await addTwoMessagesConcurrentlyReturningErrorCount(to: sut)

        // WHEN dequeue is called
        _ = try await sut.dequeue()

        // THEN the queue should have 1 message left
        let queue = await sut.testableQueue
        let fillLevel = queue?.getFillLevel(secret: testingSecret)
        XCTAssert(fillLevel == 1)

        // AND the queue in memory should be the same as the queue in the datastore
        let stored = try await testableDataStore.loadQueue()
        XCTAssert(queue == stored)
    }

    func testPeek() async throws {
        // GIVEN an initialized queue with 2 messages
        let testableDataStore = PrivateSendingQueueDataStore()
        let sut = try await PrivateSendingQueueRepository.createTestableInstance(dataStore: testableDataStore)
        try await sut.start()
        try await addTwoMessagesConcurrentlyReturningErrorCount(to: sut)

        // WHEN peek is called
        _ = try await sut.peek()
        // THEN the queue should still have 2 message left
        let queue = await sut.testableQueue
        let fillLevel = queue?.getFillLevel(secret: testingSecret)
        XCTAssert(fillLevel == 2)

        // AND the queue in memory should be the same as the queue in the datastore
        let stored = try await testableDataStore.loadQueue()
        XCTAssert(queue == stored)
    }

    func testWipe() async throws {
        let secret = PrivateSendingQueueSecret(bytes: "secret__secret__".asBytes())

        let userKeyPair: EncryptionKeypair<User> = try EncryptionKeypair<User>.generateEncryptionKeypair()
        let encryptedMessage = try await UserToCoverNodeMessage.createMessage(message: "message 1",
                                                                              recipientPublicKey: PublicKeysHelper.shared.getTestJournalistMessageKey!,
                                                                              coverNodesToMostRecentMessagePublicKey: PublicKeysHelper.shared.testKeys,
                                                                              userPublicKey: userKeyPair.publicKey, tag: RecipientTag(tag: [1, 2, 3, 4]))

        // GIVEN an initialized empty queue
        let testableDataStore = PrivateSendingQueueDataStore()
        let sut = try await PrivateSendingQueueRepository.createTestableInstance(dataStore: testableDataStore)
        try await sut.start()
        // WHEN a message is enqueue, then the queue is wiped
        let hmac = try await sut.enqueue(secret: secret!,
                                         message: encryptedMessage)

        let inQueue = await sut.isMessageInQueue(hint: hmac)

        XCTAssertTrue(inQueue)

        try await sut.wipeQueue()
        // THEN a message is no longer in the queue
        let stillInQueue = await sut.isMessageInQueue(hint: hmac)

        XCTAssertFalse(stillInQueue)
    }
}
