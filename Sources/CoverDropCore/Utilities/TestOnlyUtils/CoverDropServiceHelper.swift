import Foundation

public enum CoverDropServiceHelper {
    public static func awaitCoverDropService() async throws {
        var ready = false
        repeat {
            try await Task.sleep(nanoseconds: UInt64(0.1))
            ready = await CoverDropServices.shared.isReady
        } while ready == false
    }
}
