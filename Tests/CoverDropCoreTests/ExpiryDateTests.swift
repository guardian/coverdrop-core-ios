@testable import CoverDropCore
import Sodium
import XCTest

// This tests the 3 expiry statuses for messages
final class ExpiryDateTests: XCTestCase {
    func testExpiry() async throws {
        let now = Date()
        let calendar = Calendar.current

        let messageSend1DayAgo = await Message.outboundMessage(
            message: OutboundMessageData(
                recipient: PublicKeysHelper.shared.testDefaultJournalist!,
                messageText: "Test",
                // swiftlint:disable:next force_unwrapping
                dateQueued: calendar.date(byAdding: .day, value: -1, to: now)!,
                hint: HintHmac(hint: [0, 0, 0, 0])
            )
        )

        let expiredStatus = Message.getExpiredStatus(dateSentOrReceived: messageSend1DayAgo.getDate())
        XCTAssertEqual(expiredStatus, .pendingOrSent)

        let messageSend13DaysAgo = await Message.outboundMessage(
            message: OutboundMessageData(
                recipient: PublicKeysHelper.shared.testDefaultJournalist!,
                messageText: "Test",
                // swiftlint:disable:next force_unwrapping
                dateQueued: calendar.date(byAdding: .day, value: -13, to: now)!,
                hint: HintHmac(hint: [0, 0, 0, 0])
            )
        )

        let expiredStatus2 = Message.getExpiredStatus(dateSentOrReceived: messageSend13DaysAgo.getDate())
        XCTAssertEqual(expiredStatus2, .expiring(time: "23h"))

        let messageSend15DaysAgo = await Message.outboundMessage(
            message: OutboundMessageData(
                recipient: PublicKeysHelper.shared.testDefaultJournalist!,
                messageText: "Test",
                // swiftlint:disable:next force_unwrapping
                dateQueued: calendar.date(byAdding: .day, value: -15, to: now)!,
                hint: HintHmac(hint: [0, 0, 0, 0])
            )
        )

        let expiredStatus3 = Message.getExpiredStatus(dateSentOrReceived: messageSend15DaysAgo.getDate())
        XCTAssertEqual(expiredStatus3, .expired)
    }
}
