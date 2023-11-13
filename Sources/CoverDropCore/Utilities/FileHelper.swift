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
            let interval = try now.timeIntervalSince(getLastUpdatedDate(fileUrl: fileUrl))
            return interval > fileExpiry
        }

        return try canRefresh(now: now)
    }

    static func getLastUpdatedDate(fileUrl: URL) throws -> Date {
        let attributes: [FileAttributeKey: Any] = try FileManager.default.attributesOfItem(atPath: fileUrl.path)
        let optionalModificationDate = attributes[FileAttributeKey.modificationDate] as? Date
        guard let modificationDate = optionalModificationDate else {
            throw PublicKeyLocalRepositoryError.failedToGetModificationDate
        }
        return modificationDate
    }

    // This is for testing purposes.
    public static func setLastUpdatedDate(fileUrl: URL, now: Date) throws -> Bool {
        let attributes = [FileAttributeKey.modificationDate: now]
        if let setSuccess = try? FileManager.default.setAttributes(attributes, ofItemAtPath: fileUrl.path) {
            return true
        } else {
            return false
        }
    }
}
