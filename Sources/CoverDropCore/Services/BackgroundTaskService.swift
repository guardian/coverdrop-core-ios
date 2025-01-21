import BackgroundTasks
import Foundation

let expectedMeanDelaySeconds = 10 * 60
let minDelaySeconds = 5 * 60
let maxDelaySeconds = 120 * 60
let extraDelaySeconds = 10 * 60

public enum BackgroundTaskService {
    static var serviceName = "com.theguardian.coverdrop.reference.refresh"

    static func scheduleBackgroundSendJob(
        extraDelaySeconds: Int = 0,
        bgTaskScheduler: TaskScheduler = BGTaskScheduler.shared
    ) async {
        let request = BGAppRefreshTaskRequest(identifier: serviceName)
        let delay = try? Int(SecureRandomUtils.nextDurationFromExponentialDistribution(
            expectedMeanDuration: Duration.seconds(expectedMeanDelaySeconds),
            atLeastDuration: Duration.seconds(minDelaySeconds),
            atMostDuration: Duration.seconds(maxDelaySeconds)
        ).components.seconds) + extraDelaySeconds
        let timeDelay = TimeInterval(delay ?? expectedMeanDelaySeconds)
        request.earliestBeginDate = Date(timeIntervalSinceNow: timeDelay)

        try? bgTaskScheduler.submit(request)
        Debug.println("Background task scheduled")
    }

    static func registerBackgroundSendJob(
        config: CoverDropConfig,
        bgTaskScheduler: TaskScheduler = BGTaskScheduler.shared
    ) {
        _ = bgTaskScheduler.register(forTaskWithIdentifier: serviceName, using: nil) { task in
            // Downcast the parameter to an app refresh task as this identifier is used for a refresh request.
            Task {
                await BackgroundTaskService.handleAppRefresh(
                    task: task as! BGAppRefreshTask,
                    config: config
                )
                Debug.println("Registered Background task")
            }
        }
    }

    static func handleAppRefresh(
        task: BGAppRefreshTask,
        config: CoverDropConfig
    ) async {
        Debug.println("Background task run")
        PublicDataRepository.setup(config)
        do {
            let verifiedPublicKeys = try await PublicDataRepository.shared.loadAndVerifyPublicKeys(config: config)
            let result = await BackgroundMessageSendJob.run(
                verifiedPublicKeys: verifiedPublicKeys,
                now: Date(),
                numMessagesPerBackgroundRun: config
                    .numMessagesPerBackgroundRun,
                minDurationBetweenBackgroundRunsInSecs: config
                    .minDurationBetweenBackgroundRunsInSecs
            )

            switch result {
            case .success:
                task.setTaskCompleted(success: true)
            case .failure:
                task.setTaskCompleted(success: false)
            }
        } catch {
            task.setTaskCompleted(success: false)
        }
    }
}
