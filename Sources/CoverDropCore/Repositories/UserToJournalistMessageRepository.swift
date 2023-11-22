import Foundation

enum UserToJournalistMessagingError: Error {
    case unableToBase64Encode
    case failedToPeekMessage
    case failedToSendMessage
    case failedToDequeue
}

// MARK: - Implementation

public struct UserToJournalistMessageWebRepository: WebRepository {
    let session: URLSession
    let baseURL: String

    public init(session: URLSession = ApplicationConfig.config.urlSessionConfig(), baseUrl: String = ApplicationConfig.config.messageBaseUrl) {
        self.session = session
        baseURL = baseUrl
    }

    public func sendMessage(jsonData: Data) async throws {
        try await post(endpoint: API.sendMessage, body: jsonData)
    }
}

// MARK: - Endpoints

extension UserToJournalistMessageWebRepository {
    enum API {
        case sendMessage
    }
}

extension UserToJournalistMessageWebRepository.API: APICall {
    var path: String? {
        switch self {
        case .sendMessage:
            return "/user/messages"
        }
    }

    var method: HttpMethod {
        switch self {
        case .sendMessage:
            return .POST
        }
    }

    var headers: [String: String]? {
        return ["Accept": "application/json", "Content-Type": "application/json"]
    }
}
