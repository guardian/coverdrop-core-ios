import Combine
import Foundation

// MARK: - Implimentation

struct StatusWebRepository: CacheableWebRepository {
    typealias T = StatusData
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

    func get(params: [String: String]?) async throws -> StatusData {
        let response: StatusData = try await call(endpoint: API.status)
        return response
    }
}

// MARK: - Endpoints

extension StatusWebRepository {
    enum API {
        case status
    }
}

extension StatusWebRepository.API: APICall {
    var path: String? {
        switch self {
        case .status:
            return "/status"
        }
    }

    var method: HttpMethod {
        switch self {
        case .status:
            return .GET
        }
    }

    var headers: [String: String]? {
        return ["Accept": "application/json"]
    }

    func body() throws -> Data? {
        return nil
    }
}
