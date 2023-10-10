import Foundation
import SwiftUI

actor DeadDropIdRepository {
    private let deadDropFileLocation = "deadDropId.json"

    public func fileURL() throws -> URL {
        return try FileHelper.getPath(fileName: deadDropFileLocation)
    }

    func load() throws -> DeadDropId {
        let fileURL = try fileURL()
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(DeadDropId.self, from: data)
    }

    func save(deadDrops: DeadDropId) throws {
        let data = try JSONEncoder().encode(deadDrops)
        let outfile = try fileURL()
        try data.write(to: outfile)
    }
}
