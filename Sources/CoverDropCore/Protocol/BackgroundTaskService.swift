import BackgroundTasks
import Foundation

let expectedMeanDelaySeconds = 10 * 60
let minDelaySeconds = 5 * 60
let maxDelaySeconds = 120 * 60

public enum BackgroundTaskService {
    static var serviceName = "com.theguardian.coverdrop.reference.refresh"

    static func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: serviceName)
        let extraDelaySeconds: Int64 = 10 * 60
        let delay = try? SecureRandomUtils.nextDurationFromExponentialDistribution(
            expectedMeanDuration: Duration.seconds(expectedMeanDelaySeconds),
            atLeastDuration: Duration.seconds(minDelaySeconds),
            atMostDuration: Duration.seconds(maxDelaySeconds)
        ).components.seconds + extraDelaySeconds
        let timeDelay = TimeInterval(delay ?? Int64(expectedMeanDelaySeconds))
        request.earliestBeginDate = Date(timeIntervalSinceNow: timeDelay)

        try? BGTaskScheduler.shared.submit(request)
    }

    static func registerAppRefresh(config: CoverDropConfig) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: serviceName, using: nil) { task in
            // Downcast the parameter to an app refresh task as this identifier is used for a refresh request.
            BackgroundTaskService.handleAppRefresh(task: task as! BGAppRefreshTask, config: config)
        }
    }

    static func handleAppRefresh(task: BGAppRefreshTask, config: CoverDropConfig) {
        Task {
            let coverMessageFactoryOpt = try? await CoverDropServices
                .getCoverMessageFactoryFromPublicKeysRepository(config: config)

            guard let coverMessageFactory = coverMessageFactoryOpt else {
                task.setTaskCompleted(success: false)
                return
            }

            let result = await PublicDataRepository.shared
                .dequeueMessageAndSend(coverMessageFactory: coverMessageFactory)

            switch result {
            case .success:
                task.setTaskCompleted(success: true)
                BackgroundTaskService.scheduleAppRefresh()
            case .failure:
                task.setTaskCompleted(success: false)
            }
        }
    }
}
