import BackgroundTasks
import Foundation

public enum BackgroundTaskService {
    static var serviceName = "com.theguardian.coverdrop.reference.refresh"

    static func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: serviceName)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60) // Run no earlier than 1 minute from now

        try? BGTaskScheduler.shared.submit(request)
    }

    static func registerAppRefresh() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: serviceName, using: nil) { task in
            // Downcast the parameter to an app refresh task as this identifier is used for a refresh request.
            BackgroundTaskService.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }

    static func handleAppRefresh(task: BGAppRefreshTask) {
        Task {
            do {
                try await PublicDataRepository.shared.dequeueMessageAndSend()
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
            BackgroundTaskService.scheduleAppRefresh()
        }
    }
}
