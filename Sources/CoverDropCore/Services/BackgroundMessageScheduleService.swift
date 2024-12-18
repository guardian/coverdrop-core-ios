import BackgroundTasks
import Foundation

enum BackgroundMessageScheduleService {
    /// This should only be triggered when the app cold starts
    /// by putting a call in `didFinishLaunchingWithOptions` app delegate function.
    ///
    /// If work is pending ( got from the `BackgroundWorkPending` state ) we run immediatly
    /// If there is no work pending (note this is a rare occurrence,
    /// and the app should usually schedule work when backgrounded)
    /// we will schedule a cleanup background task
    public static func onAppStart(_ bgTaskScheduler: TaskScheduler = BGTaskScheduler.shared) async {
        let workPendingOption = PublicDataRepository.shared.readBackgroundWorkPending()
        // This is the fallback mechanism if the background task didn't run
        if let workPending = workPendingOption, workPending {
            if let config = PublicDataRepository.appConfig {
                _ = await BackgroundMessageSendJob.run(
                    config: config,
                    now: DateFunction.currentTime(),
                    numMessagesPerBackgroundRun: config.numMessagesPerBackgroundRun,
                    minDurationBetweenBackgroundRunsInSecs: config.minDurationBetweenBackgroundRunsInSecs
                )
            }
        }
        // This code always runs and schedules a background task optimistically in the future.
        // The task is likey to be overwritten when we background the app, but set it here just in case
        BackgroundTaskService.scheduleBackgroundSendJob(
            extraDelaySeconds: extraDelaySeconds,
            bgTaskScheduler: bgTaskScheduler
        )
        PublicDataRepository.shared.writeBackgroundWorkPending(true)
    }

    /// This should be called when the app enters the background from `applicationDidEnterBackground` in app delegate
    /// This will overwrite any previously scheduled background tasks with this most recent one
    public static func onEnterBackground() {
        BackgroundTaskService.scheduleBackgroundSendJob()
        PublicDataRepository.shared.writeBackgroundWorkPending(true)
    }
}
