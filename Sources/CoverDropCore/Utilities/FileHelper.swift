import Foundation

public enum FileHelper {
    public static func getPath(fileName: String) throws -> URL {
        var url = try FileManager.default.url(for: .applicationSupportDirectory,
                                              in: .userDomainMask,
                                              appropriateFor: nil,
                                              create: true)

        var fullPath = url.appendingPathComponent(fileName)
        var res = URLResourceValues()
        res.isExcludedFromBackup = true
        if FileManager.default.fileExists(atPath: fullPath.path) {
            try fullPath.setResourceValues(res)
        }
        return fullPath
    }

    public static func isFileOlderThan(durationInSeconds: Double, fileUrl: URL, now: Date) throws -> Bool {
        /// This function checks the last updated date
        /// If the time interval between now and the last updated date is greater that
        /// the file cache time, we return true
        func canRefresh(now: Date) throws -> Bool {
            let fileExpiry = Double(durationInSeconds)
            let interval = try now.timeIntervalSince(getLastUpdatedDate())
            return interval > fileExpiry
        }

        func getLastUpdatedDate() throws -> Date {
            let attributes: [FileAttributeKey: Any] = try FileManager.default.attributesOfItem(atPath: fileUrl.path)
            let optionalModificationDate = attributes[FileAttributeKey.modificationDate] as? Date
            guard let modificationDate = optionalModificationDate else {
                throw PublicKeyLocalRepositoryError.failedToGetModificationDate
            }
            return modificationDate
        }

        return try canRefresh(now: now)
    }
}
