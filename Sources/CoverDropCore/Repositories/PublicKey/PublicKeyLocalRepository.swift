import Foundation
import SwiftUI

enum PublicKeyLocalRepositoryError: Error {
    case failedToGetModificationDate
}

actor PublicKeyLocalRepository {
    let publicKeyFileLocation = "publicKeys.json"

    func fileURL() throws -> URL {
        return try FileHelper.getPath(fileName: publicKeyFileLocation)
    }

    func load() async throws -> PublicKeysData {
        let fileURL = try fileURL()
        var data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(PublicKeysData.self, from: data)
    }

    func save(publicKeys: PublicKeysData) throws {
        let data = try JSONEncoder().encode(publicKeys)
        let outfile = try fileURL()
        try data.write(to: outfile)
    }
}
