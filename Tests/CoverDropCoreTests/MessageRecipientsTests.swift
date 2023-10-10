@testable import CoverDropCore
import XCTest

// swiftlint:disable force_try

final class MessageRecipientsTests: XCTestCase {
    override func setUp() async throws {
        let config = ApplicationConfig.config
        PublicDataRepository.setup(config)
    }

    let testKeys = PublicKeysHelper.shared.testKeys
    static let sut = try! MessageRecipients(verifiedPublicKeys: PublicKeysHelper.shared.testKeys)

    func testDefaultRecipient() {
        let expectedDefaultRecipientId = testKeys.defaultJournalistId
        XCTAssert(expectedDefaultRecipientId == nil)
    }

    func testDefaultRecipientExcluded() {
        let journalistContains = MessageRecipientsTests.sut.journalists.contains(where: { $0 == MessageRecipientsTests.sut.defaultRecipient })
        XCTAssertFalse(journalistContains)

        let desksContains = MessageRecipientsTests.sut.desks.contains(where: { $0 == MessageRecipientsTests.sut.defaultRecipient })
        XCTAssertFalse(desksContains)
    }

    func testsWithUnavailableKeys() {
        do {
            _ = try MessageRecipients(verifiedPublicKeys: nil)
        } catch {
            XCTAssert(error as! MessageRecipients.RecipientsError == MessageRecipients.RecipientsError.recipientsUnavailable)
        }
    }

    // tests MessageRecipients based on `001_journalist_with_multiple_messaging_keys.json`
    func testDesks() {
        let sut = try! MessageRecipients(verifiedPublicKeys: PublicKeysHelper.shared.testKeys, excludingDefaultRecipient: false)
        let testDeskCount = 1
        XCTAssert(sut.desks.count == testDeskCount)
    }

    func testJournalists() {
        let sut = try! MessageRecipients(verifiedPublicKeys: PublicKeysHelper.shared.testKeys, excludingDefaultRecipient: false)
        let testJournalistsCount = 2
        XCTAssert(sut.journalists.count == testJournalistsCount)
    }
}
