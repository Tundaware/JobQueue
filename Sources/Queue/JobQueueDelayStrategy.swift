///
///  Created by George Cox on 1/22/20.
///

import Foundation
import ReactiveSwift
#if SWIFT_PACKAGE
import JobQueueCore
#endif

public protocol JobQueueDelayStrategy {
  /// Invoked each time the queue is synchronized
  ///
  /// - Parameter jobs: the delayed jobs in the queue
  func update(queue: JobQueue, jobs: [Job])
}

/**
 Polls queues using the provided time interval in seconds. Polling only occurs if
 there are delayed jobs in the queue.
 */
public class JobQueueDelayPollingStrategy: JobQueueDelayStrategy {
  private var disposablesByQueueName = [JobQueueName: Disposable]()
  private let interval: DispatchTimeInterval

  public init(interval: TimeInterval = 5) {
    self.interval = .milliseconds(Int(interval * 1000))
  }

  /**
   If there are no delayed jobs, polling is terminated

   If there are delayed jobs and we're already polling, this is a no-op.

   If there are delayed jobs and we're not polling yet, polling starts. Each time
   the queue is polled, we fetch all the delayed jobs from the queue and release
   any jobs that can be released by setting their status to `.waiting`. ``

   - Parameters:
    - queue: the queue the update applies to
    - jobs: the delayed jobs in the queue
   */
  public func update(queue: JobQueue, jobs: [Job]) {
    let disposable = disposablesByQueueName[queue.name]
    guard let earliestDelayedJob = jobs.earliestDelayedJob else {
      if let disposable = disposable {
        disposable.dispose()
        disposablesByQueueName.removeValue(forKey: queue.name)
      }
      return
    }
    if disposable == nil {
      disposablesByQueueName[queue.name] = SignalProducer.timer(
        interval: interval,
        on: queue.schedulers.delay
      )
      .filter { $0 > earliestDelayedJob.delayedUntil! }
      .flatMap(.concat) { now in
        queue.getAll().map { (jobs: $0, now: now) }
      }
      .map { (jobs: [Job], now: Date) in
        jobs.delayedJobs.filter { job in
          job.delayedUntil! < now
        }
      }
      .flatMap(.concat) { (jobs: [Job]) in SignalProducer(jobs) }
      .flatMap(.concat) { (job: Job) in queue.set(job.id, status: .waiting) }
      .start()
    }
  }
}
