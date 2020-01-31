///
///  Created by George Cox on 1/22/20.
///

import Foundation
import ReactiveSwift
#if SWIFT_PACKAGE
import JobQueueCore
#endif

public class InMemoryStorage: JobStorage {
  private var data = [QueueName: [Job.ID: Job]]()
  private let scheduler: Scheduler
  private let logger: Logger

  public init(scheduler: Scheduler, logger: Logger = ConsoleLogger()) {
    self.scheduler = scheduler
    self.logger = logger
  }

  public func transaction<T>(queue: QueueIdentity, _ closure: @escaping (JobStorageTransaction) throws -> T) -> SignalProducer<T, JobQueueError> {
    return SignalProducer { o, lt in
      let transaction = Transaction(queue: queue, data: self.data, logger: self.logger)

      do {
        let result = try closure(transaction)
        transaction.changes.forEach { change in
          switch change {
          case .stored(let queueName, let jobID, let job):
            self.logger.trace("Storage applying .stored(\(queueName), \(jobID), \(job.status) from tx \(transaction.id)")
            var jobs = self.data[queueName, default: [Job.ID: Job]()]
            jobs[jobID] = job
            self.data[queueName] = jobs
          case .removed(let queueName, let jobID, let job):
            guard var jobs = self.data[queueName] else {
              return
            }
            self.logger.trace("Storage applying .removed(\(queueName), \(jobID), \(job.status) from tx \(transaction.id)")
            jobs.removeValue(forKey: jobID)
            self.data[queueName] = jobs
          case .removedAll(let queueName):
            self.logger.trace("Storage applying .removedAll(\(queueName)) from tx \(transaction.id)")
            self.data.removeValue(forKey: queueName)
          }
        }
        self.logger.trace("COMMITTED TRANSACTION \(transaction.id)")
        o.send(value: result)
        o.sendCompleted()
      } catch {
        o.send(error: .from(error))
      }
    }.start(on: self.scheduler)
  }
}
