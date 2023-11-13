import Foundation
import SwiftUI

actor DeadDropLocalRepository {
    let deadDropCacheFileLocation = "deadDrops.json"

    /// Gets the file URL for deadDropCacheFileLocation
    ///
    /// - Returns: the URL to the file if it is found
    /// - Throws: if the file path is not valid
    func fileURL() throws -> URL {
        return try FileHelper.getPath(fileName: deadDropCacheFileLocation)
    }

    /// Loads the deadDrop cache file from disk and decodes to DeadDropData
    /// - Returns: DeadDropData representation of the cached dead drop json file
    /// - Throws: If decoding fails or file is not available
    func load() async throws -> DeadDropData {
        let fileURL = try fileURL()
        var data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(DeadDropData.self, from: data)
    }

    /// Saves the supplied dead drops to the local cache file
    /// - Parameter deadDrops: deadDrops to be cached.
    /// - Throws: if writing to the output file fails or JSON encoding fails
    func save(deadDrops: DeadDropData) throws {
        let data = try JSONEncoder().encode(deadDrops)
        let outfile = try fileURL()
        try data.write(to: outfile)
    }

    /// Merges two sets of dead drops, with duplicate entries being merged.
    /// Then trims the merged dead drops by `clientDeadDropCacheTtlSeconds` using the `mostRecentTimestamp`
    /// from the most recent dead drops createdAt date.
    /// Any dead drops older than `clientDeadDropCacheTtlSeconds` will be removed
    /// - Parameters:
    ///   - existingDeadDrops: a `DeadDropData` object, normally loaded from a file cache
    ///   - newDeadDrops: a `DeadDropData` object, normally loaded from the dead drop api.
    /// - Returns: The merged and trimmed resulting `DeadDropData`
    func mergeAndTrim(existingDeadDrops: DeadDropData, newDeadDrops: DeadDropData) -> DeadDropData {
        let deadDropCacheTTL = TimeInterval(Constants.clientDeadDropCacheTtlSeconds)

        var mergedDeadDrops: [DeadDrop] = existingDeadDrops.deadDrops + newDeadDrops.deadDrops

        let uniqueDeadDrops = Set(mergedDeadDrops)

        // identify the newest dead-drop timestamp. We use that as a reference for "now" to avoid
        // using the device clock which might be out-of-sync and could lead to evicting more of
        // fewer items than intended
        guard let mostRecentTimestamp = uniqueDeadDrops.max(by: { $0.createdAt < $1.createdAt }) else {
            return DeadDropData(deadDrops: [])
        }
        let cutOffDate = mostRecentTimestamp.createdAt.date - deadDropCacheTTL
        let mergedAndTrimmedDeadDrops = uniqueDeadDrops.filter { $0.createdAt.date >= cutOffDate }

        return DeadDropData(deadDrops: Array(mergedAndTrimmedDeadDrops))
    }
}
