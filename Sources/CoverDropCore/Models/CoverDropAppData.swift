import Combine
import Foundation

public class CoverDropAppData {
    // Making the initialiser private is a way to achieve the sington pattern
    private init() {}

    public static let getInstance = CoverDropAppData()

    @Published public var publicKeysData: PublicKeysData?

    public func initialise() async throws -> CoverDropAppData {
        let data = try await PublicKeyRepository().loadKeys()
        publicKeysData = data
        return self
    }
}
