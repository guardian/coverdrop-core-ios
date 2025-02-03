@testable import CoverDropCore
import XCTest

final class VerifiedDeadDropDataTests: XCTestCase {
    func testVerification() throws {
        let testContext = IntegrationTestScenarioContext(scenario: .minimal)
        let verifiedKeys = try testContext.loadKeysVerified()
        let deadDropData = try testContext.loadDeadDrop()
        let result = VerifiedDeadDrops.fromAllDeadDropData(deadDrops: deadDropData, verifiedKeys: verifiedKeys)
        XCTAssertEqual(result.deadDrops.count, 3)
    }
}
