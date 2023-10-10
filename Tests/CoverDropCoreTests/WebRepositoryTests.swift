@testable import CoverDropCore
import XCTest

final class WebRepositoryTests: XCTestCase {
    var webRepository: PublicKeyWebRepository!
    let baseUrl = "https://localhost/v1"

    override func setUp() {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockURLProtocol.self]
        let urlSession = URLSession(configuration: configuration)

        webRepository = PublicKeyWebRepository(session: urlSession, baseUrl: baseUrl)
    }

    func testTextJsonDecoding() async throws {
        let results = try PublicKeysHelper.readLocalKeysFile()
        XCTAssertTrue(results.keys.first?.journalists.first?.journalists.keys.firstIndex(of: "static_test_journalist") != nil)
    }
}
