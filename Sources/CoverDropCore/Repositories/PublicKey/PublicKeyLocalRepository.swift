import Foundation
import SwiftUI

enum PublicKeyLocalRepositoryError: Error {
    case failedToGetModificationDate
}

actor PublicKeyLocalRepository: LocalCacheFileRepository {
    let fileLocation = "publicKeys.json"

    func fileURL() throws -> URL {
        return try FileHelper.getPath(fileName: fileLocation)
    }

    func load() async throws -> PublicKeysData {
        let fileURL = try fileURL()
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(PublicKeysData.self, from: data)
    }

    func save(data: PublicKeysData) async throws {
        let encodedData = try JSONEncoder().encode(data)
        let outfile = try fileURL()
        try encodedData.write(to: outfile)
    }
}
