@testable import CoverDropCore
import Sodium
import XCTest

final class DeadDropLocalRepositoryTests: XCTestCase {
    func removeCurrentCacheFile() async throws {
        let fileManager = FileManager.default
        let fileURL = try await DeadDropIdRepository().fileURL()

        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(atPath: fileURL.path)
        }
    }

    func fakeUserFacingDeadDrop(id: Int, createdAt: Date) -> DeadDrop {
        let emptyMessage = Base64EncodedString(bytes: "".asBytes())
        let emptyCert = HexEncodedString(bytes: "".asBytes())
        return DeadDrop(id: id, createdAt: RFC3339DateTimeString(date: createdAt), data: emptyMessage, cert: emptyCert)
    }

    func testDeadDrops_whenDownloadedWithNonEmptyStorage_thenMergedTrimmedAndAvailableAsMostRecent() async throws {
        let deadDropApril01 = fakeUserFacingDeadDrop(id: 10, createdAt: DateFormats.validateDate(date: "2023-04-01T00:00:00Z") ?? Date())
        let deadDropApril05 = fakeUserFacingDeadDrop(id: 20, createdAt: DateFormats.validateDate(date: "2023-04-05T00:00:00Z") ?? Date())
        let deadDropApril06 = fakeUserFacingDeadDrop(id: 21, createdAt: DateFormats.validateDate(date: "2023-04-06T00:00:00Z") ?? Date())
        let deadDropApril10 = fakeUserFacingDeadDrop(id: 40, createdAt: DateFormats.validateDate(date: "2023-04-10T00:00:00Z") ?? Date())
        let deadDropApril11 = fakeUserFacingDeadDrop(id: 50, createdAt: DateFormats.validateDate(date: "2023-04-11T00:00:00Z") ?? Date())
        let deadDropApril20 = fakeUserFacingDeadDrop(id: 80, createdAt: DateFormats.validateDate(date: "2023-04-20T00:00:00Z") ?? Date())
        let deadDropJune01 = fakeUserFacingDeadDrop(id: 200, createdAt: DateFormats.validateDate(date: "2023-06-01T00:00:00Z") ?? Date())
        let deadDropJune07 = fakeUserFacingDeadDrop(id: 201, createdAt: DateFormats.validateDate(date: "2023-06-01T00:00:00Z") ?? Date())

        // Start with an empty storage
        var existingDeadDrops = DeadDropData(deadDrops: [])

        // Add dead drops on April 10 that range from April 1 to April 10
        let newDeadDropsApril10 = DeadDropData(deadDrops:
                                                [deadDropApril01, deadDropApril05, deadDropApril06, deadDropApril10]
        )

        // After merging and trimming we expect that we only have dead drops that range from
        // April 1 to April 10. I.e., all of them
        existingDeadDrops = await DeadDropLocalRepository().mergeAndTrim(existingDeadDrops: existingDeadDrops, newDeadDrops: newDeadDropsApril10)
        XCTAssertTrue(existingDeadDrops.deadDrops.containsExactly([
            deadDropApril01,
            deadDropApril05,
            deadDropApril06,
            deadDropApril10
        ]))

        // Add dead drops on April 20 that range from April 11 to April 20
        let newDeadDropsApril20 = DeadDropData(deadDrops:
                                                [deadDropApril11, deadDropApril20]
        )

        // After merging and trimming we expect that we only have dead drops that range from
        // April 6 to April 20 (i.e. deadDropCacheTTL).
        existingDeadDrops = await DeadDropLocalRepository().mergeAndTrim(existingDeadDrops: existingDeadDrops, newDeadDrops: newDeadDropsApril20)
        XCTAssertTrue(existingDeadDrops.deadDrops.containsExactly(
                        [deadDropApril06, // just barely in by 1 second because the cut-off-date is inclusive
                         deadDropApril10,
                         deadDropApril11,
                         deadDropApril20]))

        // Add dead drops on June 7 that range from June 1 to June 7
        let newDeadDropsJune07 = DeadDropData(deadDrops:
                                                [deadDropJune01, deadDropJune07]
        )

        // After merging and trimming we expect that we only have dead drops that range from
        // June 1 to June 7.
        existingDeadDrops = await DeadDropLocalRepository().mergeAndTrim(existingDeadDrops: existingDeadDrops, newDeadDrops: newDeadDropsJune07)
        XCTAssertTrue(existingDeadDrops.deadDrops.containsExactly(
                        [deadDropJune01,
                         deadDropJune07]))
    }
}
