import Foundation

protocol LocalCacheFileRepository<T> {
    associatedtype T: Codable
    var fileLocation: String { get }

    /// Gets the file URL for fileLocation
    ///
    /// - Returns: the URL to the file if it is found
    /// - Throws: if the file path is not valid
    func fileURL() async throws -> URL

    /// Loads the cache file from disk and decodes to T
    /// - Returns: T representation of the cached dead drop json file
    /// - Throws: If decoding fails or file is not available
    func load() async throws -> T

    /// Saves the supplied data to the local cache file
    /// - Parameter T: T data to be cached.
    /// - Throws: if writing to the output file fails or JSON encoding fails
    func save(data: T) async throws
}
