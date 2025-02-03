import Foundation

public enum BackgroundMessageSendState {
    static let PendingKey = "CoverDropBackgroundWorkPending"

    static func initBackgroundMessageSendState(config: CoverDropConfig) {
        if BackgroundMessageSendState.readBackgroundWorkLastSuccessfulRun() == nil {
            let now = DateFunction.currentTime()
            let oneEpochAgo = now.advanced(by: TimeInterval(0 - config.minDurationBetweenBackgroundRunsInSecs))
            BackgroundMessageSendState.writeBackgroundWorkLastSuccessfulRun(instant: oneEpochAgo)
            BackgroundMessageSendState.writeBackgroundWorkPending(false)
        }
    }

    static func writeBackgroundWorkPending(_ result: Bool) {
        UserDefaults.standard.set(result, forKey: BackgroundMessageSendState.PendingKey)
    }

    static func readBackgroundWorkPending() -> Bool? {
        UserDefaults.standard
            .object(forKey: BackgroundMessageSendState.PendingKey) as? Bool
    }

    static let LastSuccessfulRunTimeKey = "CoverDropBackgroundWorkLastSuccessfulRunTimestamp"

    static func writeBackgroundWorkLastSuccessfulRun(instant: Date) {
        UserDefaults.standard.set(
            instant,
            forKey: BackgroundMessageSendState.LastSuccessfulRunTimeKey
        )
    }

    static func readBackgroundWorkLastSuccessfulRun() -> Date? {
        return UserDefaults.standard
            .object(forKey: BackgroundMessageSendState.LastSuccessfulRunTimeKey) as? Date
    }
}
