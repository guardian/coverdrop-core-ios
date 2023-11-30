import Combine
import Foundation

// MARK: - Implimentation

struct DeadDropWebRepository: CacheableWebRepository {
    typealias T = DeadDropData

    let session: URLSession
    let baseURL: String

    init(session: URLSession,
         baseUrl: String = ApplicationConfig.config.apiBaseUrl) {
        self.session = session
        baseURL = baseUrl
    }

    func get(params: [String: String]?) async throws -> DeadDropData {
        let response: DeadDropData = try await call(endpoint: API.allDeadDrops(params: params))
        return response
    }
}

// MARK: - Endpoints

extension DeadDropWebRepository {
    enum API {
        case allDeadDrops(params: [String: String]?)
    }
}

extension DeadDropWebRepository.API: APICall {
    var path: String? {
        switch self {
        case let .allDeadDrops(params: params):
            guard let params,
                  let id = params["ids_greater_than"]
            else {
                return nil
            }
            return "/user/dead-drops?ids_greater_than=\(id)"
        }
    }

    var method: HttpMethod {
        switch self {
        case .allDeadDrops:
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
