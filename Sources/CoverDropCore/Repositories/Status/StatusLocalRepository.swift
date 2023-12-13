import Foundation
import SwiftUI

enum StatusLocalRepositoryError: Error {
    case failedToGetModificationDate
}

actor StatusLocalRepository: LocalCacheFileRepository {
    let fileLocation = "status.json"

    func fileURL() throws -> URL {
        return try FileHelper.getPath(fileName: fileLocation)
    }

    func load() async throws -> StatusData {
        let fileURL = try fileURL()
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(StatusData.self, from: data)
    }

    func save(data: StatusData) async throws {
        let encodedData = try JSONEncoder().encode(data)
        let outfile = try fileURL()
        try encodedData.write(to: outfile)
    }
}
