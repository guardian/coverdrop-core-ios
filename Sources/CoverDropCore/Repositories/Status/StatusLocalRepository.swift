import Foundation
import SwiftUI

enum StatusLocalRepositoryError: Error {
    case failedToGetModificationDate
}

actor StatusLocalRepository {
    let publicKeyFileLocation = "status.json"

    func fileURL() throws -> URL {
        return try FileHelper.getPath(fileName: publicKeyFileLocation)
    }

    func load() async throws -> StatusData {
        let fileURL = try fileURL()
        var data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(StatusData.self, from: data)
    }

    func save(status: StatusData) throws {
        let data = try JSONEncoder().encode(status)
        let outfile = try fileURL()
        try data.write(to: outfile)
    }
}
