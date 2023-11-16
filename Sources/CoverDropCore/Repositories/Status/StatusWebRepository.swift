import Combine
import Foundation

// MARK: - Protocol

protocol StatusWebRepositoryProtocol: WebRepository {
    func loadStatus() async throws -> StatusData
}

// MARK: - Implimentation

struct StatusWebRepository: StatusWebRepositoryProtocol {
    let session: URLSession
    let baseURL: String

    init() {
        session = ApplicationConfig.config.urlSessionConfig()
        baseURL = ApplicationConfig.config.apiBaseUrl
    }

    init(session: URLSession, baseUrl: String = ApplicationConfig.config.apiBaseUrl) {
        self.session = session
        baseURL = baseUrl
    }

    func loadStatus() async throws -> StatusData {
        return try await call(endpoint: API.status)
    }
}

// MARK: - Endpoints

extension StatusWebRepository {
    enum API {
        case status
    }
}

extension StatusWebRepository.API: APICall {
    var path: String {
        switch self {
            case .status:
                return "/status"
        }
    }

    var method: String {
        switch self {
            case .status:
                return "GET"
        }
    }

    var headers: [String: String]? {
        return ["Accept": "application/json"]
    }

    func body() throws -> Data? {
        return nil
    }
}
