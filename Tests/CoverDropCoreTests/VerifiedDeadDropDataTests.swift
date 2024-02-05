@testable import CoverDropCore
import Sodium
import XCTest

final class VerifiedDeadDropDataTests: XCTestCase {
    func testVerification() throws {
        let data = try DeadDropDataHelper.shared.readLocalDataFile()
        let key = PublicKeysHelper.shared.testKeys
        let result = VerifiedDeadDrops.fromAllDeadDropData(deadDrops: data, verifiedKeys: key)
        XCTAssertTrue(result.deadDrops.count == 1)
    }
}
