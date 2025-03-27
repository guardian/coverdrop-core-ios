import Foundation

public enum FileHelper {
    public static func getPath(fileName: String) throws -> URL {
        let url = try FileManager.default.url(for: .applicationSupportDirectory,
                                              in: .userDomainMask,
                                              appropriateFor: nil,
                                              create: true)

        // The application support directory isn't automatically created on app install
        // So we have to check it exists and create it if not.
        try ensureApplicationSupportDirectory(at: url.path())

        var fullPath = url.appendingPathComponent(fileName)
        // File protection options can cause issues accessing files
        // when we are in the background, so we make sure they are not set
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.none],
            ofItemAtPath: fullPath.absoluteString
        )
        var res = URLResourceValues()
        res.isExcludedFromBackup = true
        if FileManager.default.fileExists(atPath: fullPath.path) {
            try fullPath.setResourceValues(res)
        }
        return fullPath
    }

    public static func ensureApplicationSupportDirectory(at path: String) throws {
        if !FileManager.default.fileExists(atPath: path) {
            try FileManager.default.createDirectory(
                atPath: path,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }

    /// This function checks the last updated date
    /// If the time interval between now and the last updated date is greater that
    /// the file cache time, we return true
    public static func isFileOlderThan(durationInSeconds: TimeInterval, fileUrl: URL, now: Date) -> Bool {
        if let interval = try? now.timeIntervalSince(getLastUpdatedDate(fileUrl: fileUrl)) {
            return interval > durationInSeconds
        } else {
            // as this is used to see if a cache file needs to be refresh,
            // we default to true on error which would result in a attempt to refresh the cache
            return true
        }
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
        return (try? FileManager.default.setAttributes(attributes, ofItemAtPath: fileUrl.path)) != nil
    }
}
