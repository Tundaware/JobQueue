///
///  Created by George Cox on 1/22/20.
///

import Foundation
import ReactiveSwift

public extension Queue {
  struct Schedulers {
    public let synchronize: Scheduler
    public let synchronizePending: DateScheduler
    public let storage: Scheduler
    public let delay: DateScheduler
    public let events: Scheduler

    /**
     Initializes a `JobQueueSchedulers` instance.

     - Parameter synchronize: A `Scheduler` used to schedule the queue's synchronization
     procedure.
     - Parameter shouldSynchronize: A `Scheduler` used to monitor the queue's internal
     state to determine when synchronization should occur.
     - Parameter storage: A `Scheduler` used by the queue's `JobStorage` implementation
     to schedule access to the underlying storage mechanism.
     - Parameter delay: A `DateScheduler` used by the queue to check for delayed
     jobs that can be moved to the `waiting` status.
     - Parameter events: A `Scheduler` used by the queue to send events
     */
    public init(
      synchronize: Scheduler = QueueScheduler(
        qos: .background,
        name: "JobQueue.synchronize",
        targeting: DispatchQueue(label: "JobQueue.synchronize")),
      synchronizePending: DateScheduler = QueueScheduler(
        qos: .background,
        name: "JobQueue.synchronizePending",
        targeting: DispatchQueue(label: "JobQueue.synchronizePending")),
      storage: Scheduler = QueueScheduler(
        qos: .background,
        name: "JobQueue.storage",
        targeting: DispatchQueue(label: "JobQueue.storage")),
      delay: DateScheduler = QueueScheduler(
        qos: .background,
        name: "JobQueue.delay",
        targeting: DispatchQueue(label: "JobQueue.delay")),
      events: Scheduler = QueueScheduler(
        qos: .background,
        name: "JobQueue.events",
        targeting: DispatchQueue(label: "JobQueue.events"))) {
      self.synchronize = synchronize
      self.synchronizePending = synchronizePending
      self.storage = storage
      self.delay = delay
      self.events = events
    }
  }
}
