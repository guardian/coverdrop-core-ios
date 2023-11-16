import Foundation

protocol WebRepository {
    var session: URLSession { get }
    var baseURL: String { get }
}

extension WebRepository {
    func call<Value>(endpoint: APICall, httpCodes _: HTTPCodes = .success) async throws -> Value
        where Value: Decodable
    {
        do {
            let request = try endpoint.urlRequest(baseURL: baseURL)

            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  HTTPCodes.success.contains(httpResponse.statusCode)
            else {
                throw URLError(.badServerResponse)
            }
            Debug.println(String(decoding: data, as: UTF8.self))

            let decoded = try JSONDecoder().decode(Value.self, from: data)
            Debug.println(decoded)

            return decoded
        } catch {
            throw URLError(.badServerResponse)
        }
    }

    func post(endpoint: APICall, httpCodes _: HTTPCodes = .success, body: Data?) async throws {
        let request = try endpoint.urlRequest(baseURL: baseURL, body: body)
        let (body, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              HTTPCodes.success.contains(httpResponse.statusCode)
        else {
            throw URLError(.badServerResponse)
        }
    }
}
