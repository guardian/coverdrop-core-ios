@testable import CoverDropCore
import Foundation
import XCTest

final class PrivateSendingQueueDiskStoringTests: XCTestCase {
    func testSaving() async throws {
        // GIVEN a PrivateSendingQueueDataStore and PrivateSendingQueue are initialized
        let sut = PrivateSendingQueueDataStore()
        let defaultConfig = PrivateSendingQueueConfiguration.default
        let queue = try PrivateSendingQueue(totalQueueSize: defaultConfig.totalQueueSize,
                                            messageSize: defaultConfig.messageSize)

        // WHEN that queue is saved to the store
        try await sut.saveQueue(queue)

        // THEN if the queue is later loaded from disk, it is equivalent to the queue in memory
        let fileURL = try PrivateSendingQueueDataStore.privateSendingQueueStorageFileURL
        let fileContents = try Data(contentsOf: fileURL)
        let newQueue = try PrivateSendingQueue.fromBytes(bytes: Array(fileContents))
        XCTAssert(newQueue == queue)
    }

    func testLoading() async throws {
        // GIVEN a PrivateSendingQueueDataStore and PrivateSendingQueue are initialized,
        // and a message is added to the queue, and then saved to disk
        let sut = PrivateSendingQueueDataStore()
        let defaultConfig = PrivateSendingQueueConfiguration.default
        var queue = try PrivateSendingQueue(totalQueueSize: defaultConfig.totalQueueSize,
                                            messageSize: defaultConfig.messageSize)
        let message = try await PrivateSendingQueueTests().message1()
        try queue.enqueue(secret: PrivateSendingQueueTests().secret!,
                          message: message)
        try await sut.saveQueue(queue)

        // WHEN that queue is loaded from disk
        let newQueue = try await sut.loadQueue()

        // THEN that queue is equivalent to the queue in memory
        XCTAssert(newQueue == queue)

        // AND the queue remains on disk after being loaded once (do the same action again)
        let newestQueue = try await sut.loadQueue()
        XCTAssert(newestQueue == queue)
    }
}
