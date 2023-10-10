import Foundation

enum UserToJournalistMessagingError: Error {
    case unableToBase64Encode
    case failedToPeekMessage
    case failedToSendMessage
    case failedToDequeue
}

// MARK: - Protocol

protocol UserToJournalistMessaging: WebRepository {
    func sendMessage(message: MultiAnonymousBox<UserToCoverNodeMessageData>) async throws
    func dequeueMessageAndSend(privateSendingQueue: PrivateSendingQueueRepository) async throws
}

// MARK: - Implementation

public struct UserToJournalistMessageWebRepository: UserToJournalistMessaging {
    let session: URLSession
    let baseURL: String

    public init(session: URLSession = ApplicationConfig.config.urlSessionConfig(), baseUrl: String = ApplicationConfig.config.messageBaseUrl) {
        self.session = session
        baseURL = baseUrl
    }

    public func sendMessage(message: MultiAnonymousBox<UserToCoverNodeMessageData>) async throws {
        if let data = message.asBytes().base64Encode() {
            let jsonData: Data = try JSONEncoder().encode(data)
            guard let postResponse = try? await post(endpoint: API.sendMessage, body: jsonData) else {
                throw UserToJournalistMessagingError.failedToSendMessage
            }
        } else {
            throw UserToJournalistMessagingError.unableToBase64Encode
        }
    }

    /// This dequeues a message from the `PrivateSendingQueue` and sends it to the user to journalist
    /// message api
    /// 1. dequeue message from privateSendingQueue
    /// 2. send to the api
    public func dequeueMessageAndSend(privateSendingQueue: PrivateSendingQueueRepository = PrivateSendingQueueRepository.shared) async throws {
        if let message = try? await privateSendingQueue.peek() {
            if let messageResult = try? await sendMessage(message: message) {
                guard let dequeueResult = try? await privateSendingQueue.dequeue() else {
                    throw UserToJournalistMessagingError.failedToDequeue
                }
            } else {
                throw UserToJournalistMessagingError.failedToSendMessage
            }
        } else {
            throw UserToJournalistMessagingError.failedToPeekMessage
        }
    }
}

// MARK: - Endpoints

extension UserToJournalistMessageWebRepository {
    enum API {
        case sendMessage
    }
}

extension UserToJournalistMessageWebRepository.API: APICall {
    var path: String {
        switch self {
        case .sendMessage:
            return "/user/messages"
        }
    }

    var method: String {
        switch self {
        case .sendMessage:
            return "POST"
        }
    }

    var headers: [String: String]? {
        return ["Accept": "application/json", "Content-Type": "application/json"]
    }
}
