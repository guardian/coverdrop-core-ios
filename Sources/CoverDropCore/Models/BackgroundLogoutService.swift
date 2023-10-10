import CryptoKit
import Foundation

enum BackgroundLogoutServiceError: Error {
    case missingLastBackgroundDateConfig
}

/// This service measures the time the user has backgrounded the app for, and then logs them out by
/// locking the `secretData` if they are logged in and have exceeded the `maxBackgroundDurationInSeconds`
public enum BackgroundLogoutService {
    public static func logoutIfBackgroundedForTooLong() async throws {
        guard let lastBackgroundDate = UserDefaults.standard.object(forKey: "LastBackgroundDate") as? Date,
              let appConfig = PublicDataRepository.appConfig else { throw BackgroundLogoutServiceError.missingLastBackgroundDateConfig }

        let timeIntervalSinceLastBackground = Date().timeIntervalSince(lastBackgroundDate)
        if timeIntervalSinceLastBackground > TimeInterval(appConfig.maxBackgroundDurationInSeconds) {
            if case let .unlockedSecretData(unlockedData: unlockedSecretData) = await SecretDataRepository.shared.secretData {
                try await SecretDataRepository.shared.lock(data: unlockedSecretData, withSecureEnclave: SecureEnclave.isAvailable)
            }
        }
    }
}
