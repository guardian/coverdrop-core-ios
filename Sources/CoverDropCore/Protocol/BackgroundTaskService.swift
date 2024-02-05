import BackgroundTasks
import Foundation

public enum BackgroundTaskService {
    static var serviceName = "com.theguardian.coverdrop.reference.refresh"

    static func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: serviceName)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60) // Run no earlier than 1 minute from now

        try? BGTaskScheduler.shared.submit(request)
    }

    static func registerAppRefresh(config: ConfigType) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: serviceName, using: nil) { task in
            // Downcast the parameter to an app refresh task as this identifier is used for a refresh request.
            BackgroundTaskService.handleAppRefresh(task: task as! BGAppRefreshTask, config: config)
        }
    }

    static func handleAppRefresh(task: BGAppRefreshTask, config: ConfigType) {
        Task {
            let coverMessageFactoryOpt = try? await CoverDropServices.getCoverMessageFactoryFromPublicKeysRepository(config: config)

            guard let coverMessageFactory = coverMessageFactoryOpt else {
                task.setTaskCompleted(success: false)
                return
            }

            let result = await PublicDataRepository.shared.dequeueMessageAndSend(coverMessageFactory: coverMessageFactory)

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
