import Foundation

/// This repository actor is the main interface for the app for creating and managing its instance of the global `PrivateSendingQueue` via a  `shared` singleton instance.
public actor PrivateSendingQueueRepository: ObservableObject {
    public static let shared = PrivateSendingQueueRepository()
    public var isReady: Bool {
        queue != nil
    }

    @Published public var lastUpdated: Date = .now

    // Intentionally fileprivate to allow for access by the `TestablePrivateSendingQueueRepository` protocol
    fileprivate private(set) var queue: PrivateSendingQueue? // swiftlint:disable:this private_over_fileprivate
    private let dataStore: PrivateSendingQueueDataStoring

    /// A `fileprivate` initializer for the `PrivateSendingQueueRepository`. Do not create instances of the repository directly, other than thorugh the `TestablePrivateSendingQueueRepository` protocol methods for testing purposes. Access the shared singelton instance instead.
    fileprivate init(dataStore: PrivateSendingQueueDataStoring = PrivateSendingQueueDataStore(),
                     queue: PrivateSendingQueue? = nil) {
        self.dataStore = dataStore
        if let queue {
            self.queue = queue
        }
    }

    /// Starts the repository by creating the `PrivateSendingQueue` and storing it to disk. This method *must* be called once on app start before accessing any other actor methods to ensure setup is complete.
    /// - Parameter configuration: An optional configuration for setting up the managed`PrivateSendingQueue`.
    public func start(with configuration: PrivateSendingQueueConfiguration = PrivateSendingQueueConfiguration.default, coverMessageFactory: () throws -> MultiAnonymousBox<UserToCoverNodeMessageData>) async throws {
        if queue == nil {
            queue = try PrivateSendingQueue(totalQueueSize: configuration.totalQueueSize,
                                            messageSize: configuration.messageSize, coverMessageFactory: coverMessageFactory)
        }
        try await dataStore.saveQueue(queue)
    }

    /// Removes the current queue, by generating a new `PrivateSendingQueue` and storing to disk
    /// This is so we can remove any pending real messages from users if they choose to delete all messages.
    /// - Parameter configuration: An optional configuration for setting up the managed`PrivateSendingQueue`.
    public func wipeQueue(with configuration: PrivateSendingQueueConfiguration = PrivateSendingQueueConfiguration.default, coverMessageFactory: () throws -> MultiAnonymousBox<UserToCoverNodeMessageData>) async throws {
        queue = try PrivateSendingQueue(totalQueueSize: configuration.totalQueueSize,
                                        messageSize: configuration.messageSize, coverMessageFactory: coverMessageFactory)
        try await dataStore.saveQueue(queue)
    }

    /// Enqueues the given message by calling the the `PrivateSendingQueue`'s `enqueue(..)` method and storing the changed state to disk.
    public func enqueue(secret: PrivateSendingQueueSecret, message: MultiAnonymousBox<UserToCoverNodeMessageData>) async throws -> HintHmac {
        precondition(queue != nil, "Private sending queue is nil. Ensure you are calling `start` before making this method call.")
        let hint = try queue!.enqueue(secret: secret, message: message)
        try await dataStore.saveQueue(queue!)
        lastUpdated = Date.now
        return hint
    }

    /// Dequeues a message by calling the the `PrivateSendingQueue`'s `dequeue(..)` method and storing the changed state to disk.
    func dequeue(coverMessageFactory: () throws -> MultiAnonymousBox<UserToCoverNodeMessageData>) async throws -> MultiAnonymousBox<UserToCoverNodeMessageData> {
        precondition(queue != nil, "Private sending queue is nil. Ensure you are calling `start` before making this method call.")
        let message = try queue!.sendHeadMessageAndPushNewCoverMessage(coverMessageFactory: coverMessageFactory)
        try await dataStore.saveQueue(queue!)
        lastUpdated = Date.now
        return message
    }

    /// Dequeues a message by calling the the `PrivateSendingQueue`'s `dequeue(..)` method and storing the changed state to disk.
    public func peek() async throws -> MultiAnonymousBox<UserToCoverNodeMessageData> {
        precondition(queue != nil, "Private sending queue is nil. Ensure you are calling `start` before making this method call.")
        let message = try queue!.peek()
        return message
    }

    /// Checks a message in still in the outbound queue using `PrivateSendingQueue`'s `isMessageStillInQueue(..)` method.
    public func isMessageInQueue(hint: HintHmac) -> Bool {
        precondition(queue != nil, "Private sending queue is nil. Ensure you are calling `start` before making this method call.")
        let message = queue!.isMessageStillInQueue(hint: hint)
        return message
    }
}

// MARK: Functionality to support testing

protocol TestablePrivateSendingQueueRepository {
    /// Creates an instance of `PrivateSendingQueueRepository` - to be used for testing purposes only.
    /// - Parameters:
    ///   - dataStore: defaults to an instance of `PrivateSendingQueueDataStore`
    ///   - queue: an optional queue. Defaults to `nil`. When this is `nil`,  calling `start` will instantiate an instance of `PrivateSendingQueue` with the default configuration.
    /// - Returns: A testable, started, instance of `PrivateSendingQueueRepository`
    /// - Parameters:

    static func createTestableInstance(dataStore: PrivateSendingQueueDataStoring,
                                       queue: PrivateSendingQueue?, coverMessageFactory: () throws -> MultiAnonymousBox<UserToCoverNodeMessageData>) async throws -> PrivateSendingQueueRepository

    /// An unsafe accessor to the repository's private `PrivateSendingQueue`, for testing purposes only.
    var testableQueue: PrivateSendingQueue? { get async }
}

extension PrivateSendingQueueRepository: TestablePrivateSendingQueueRepository {
    static func createTestableInstance(dataStore: PrivateSendingQueueDataStoring = PrivateSendingQueueDataStore(),
                                       queue: PrivateSendingQueue? = nil, coverMessageFactory: () throws -> MultiAnonymousBox<UserToCoverNodeMessageData>) async throws -> PrivateSendingQueueRepository {
        let repo = PrivateSendingQueueRepository(dataStore: dataStore, queue: queue)
        return repo
    }

    var testableQueue: PrivateSendingQueue? { queue }
}
