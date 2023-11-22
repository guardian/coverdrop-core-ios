import Combine
import Foundation

// MARK: - Implimentation

struct PublicKeyWebRepository: CacheableWebRepository {
    typealias T = PublicKeysData

    func get(params: [String: String]? = [:]) async throws -> PublicKeysData {
        let result: PublicKeysData = try await call(endpoint: API.allKeys)
        return result
    }

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
}

// MARK: - Endpoints

extension PublicKeyWebRepository {
    enum API {
        case allKeys
    }
}

extension PublicKeyWebRepository.API: APICall {
    var path: String? {
        switch self {
        case .allKeys:
            return "/public-keys"
        }
    }

    var method: HttpMethod {
        switch self {
        case .allKeys:
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
