import Foundation

class FileHelper {
    public func bytesFromFile(filePath: String) throws -> [UInt8]? {
        // If you see the error `Bundle.module not available` it means you've not copied the test
        // vectors into the `Resources` folder, check `Resources/README.md for details
        guard let resourceUrl = Bundle.module.url(forResource: filePath, withExtension: nil) else { return nil }
        guard let data = NSData(contentsOf: resourceUrl) else { return nil }

        return [UInt8](data)
    }
}
