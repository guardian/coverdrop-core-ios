import Foundation

protocol PrivateSendingQueueDataStoring {
    /// Loads the private sending queue from disk, if one exists
    func loadQueue() async throws -> PrivateSendingQueue?

    /// Saves the given `queue` to disk, optionally returning the same queue
    @discardableResult func saveQueue(_ currentQueue: PrivateSendingQueue?) async throws -> PrivateSendingQueue
    static var privateSendingQueueStorageFileURL: URL { get throws }
}

actor PrivateSendingQueueDataStore: PrivateSendingQueueDataStoring {
    enum PrivateSendingQueueDataStoreError: Error {
        case queueNotInitialised
    }

    private static let fileName = "privateSendingQueue"

    static var privateSendingQueueStorageFileURL: URL {
        get throws {
            try FileHelper.getPath(fileName: fileName)
        }
    }

    func loadQueue() async throws -> PrivateSendingQueue? {
        let fileURL = try PrivateSendingQueueDataStore.privateSendingQueueStorageFileURL

        if FileManager.default.fileExists(atPath: fileURL.path) {
            let fileContents = try Data(contentsOf: fileURL)
            return try PrivateSendingQueue.fromBytes(bytes: Array(fileContents))
        } else {
            return nil
        }
    }

    @discardableResult
    func saveQueue(_ currentQueue: PrivateSendingQueue?) async throws -> PrivateSendingQueue {
        guard let currentQueue else {
            throw PrivateSendingQueueDataStoreError.queueNotInitialised
        }
        let fileURL = try PrivateSendingQueueDataStore.privateSendingQueueStorageFileURL
        try Data(currentQueue.serialize()).write(to: fileURL, options: .completeFileProtection)
        return currentQueue
    }
}
