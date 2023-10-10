import Combine
import Foundation

// MARK: - Protocol

protocol PublicKeyWebRepositoryProtocol: WebRepository {
    func loadKeys() async throws -> PublicKeysData
}

// MARK: - Implimentation

struct PublicKeyWebRepository: PublicKeyWebRepositoryProtocol {
    let session: URLSession
    let baseURL: String

    init() {
        session = ApplicationConfig.config.urlSessionConfig()
        baseURL = ApplicationConfig.config.apiBaseUrl
    }

    init(session: URLSession, baseUrl: String) {
        self.session = session
        baseURL = baseUrl
    }

    func loadKeys() async throws -> PublicKeysData {
        return try await call(endpoint: API.allKeys)
    }
}

// MARK: - Endpoints

extension PublicKeyWebRepository {
    enum API {
        case allKeys
    }
}

extension PublicKeyWebRepository.API: APICall {
    var path: String {
        switch self {
        case .allKeys:
            return "/public-keys"
        }
    }

    var method: String {
        switch self {
        case .allKeys:
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
