import Combine
import Foundation

// MARK: - Protocol

protocol DeadDropWebRepositoryProtocol: WebRepository {
    func loadDeadDrops(id: Int) async throws -> DeadDropData
}

// MARK: - Implimentation

struct DeadDropWebRepository: DeadDropWebRepositoryProtocol {
    let session: URLSession
    let baseURL: String

    init(session: URLSession,
         baseUrl: String = ApplicationConfig.config.apiBaseUrl)
    {
        self.session = session
        baseURL = baseUrl
    }

    func loadDeadDrops(id: Int) async throws -> DeadDropData {
        let response: DeadDropData = try await call(endpoint: API.allDeadDrops(idsGreaterThan: id))
        return response
    }
}

// MARK: - Endpoints

extension DeadDropWebRepository {
    enum API {
        case allDeadDrops(idsGreaterThan: Int)
    }
}

extension DeadDropWebRepository.API: APICall {
    var path: String {
        switch self {
        case let .allDeadDrops(idsGreaterThan: idsGreaterThan):
            return "/user/dead-drops?ids_greater_than=\(idsGreaterThan)"
        }
    }

    var method: String {
        switch self {
        case .allDeadDrops:
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
