///
///  Created by George Cox on 1/27/20.
///

import Foundation
import ReactiveSwift
#if SWIFT_PACKAGE
import JobQueueCore
#endif

extension InMemoryStorage {
  public class Transaction: JobStorageTransaction {
    enum Change {
      case stored(QueueName, Job.ID, Job)
      case removed(QueueName, Job.ID, Job)
      case removedAll(QueueName)
    }

    private let logger: Logger
    private var data: [QueueName: [Job.ID: Job]]
    private var queue: QueueIdentity?

    internal var changes = [Change]()
    internal let id = UUID().uuidString

    public init(
      queue: QueueIdentity? = nil,
      data: [QueueName: [Job.ID: Job]],
      logger: Logger
    ) {
      self.logger = logger
      self.queue = queue
      self.data = data
    }

    public func get(_ id: Job.ID, queue: QueueIdentity?) -> Result<Job, JobQueueError> {
      guard let queue = (queue ?? self.queue) else {
        return .failure(.noQueueProvided)
      }
      guard let jobs = self.data[queue.name] else {
        return .failure(.queueNotFound(queue.name))
      }
      guard let job = jobs[id] else {
        return .failure(.jobNotFound(queue.name, id))
      }
      return .success(job)
    }

    public func getAll(queue: QueueIdentity?) -> Result<[Job], JobQueueError> {
      guard let queue = (queue ?? self.queue) else {
        return .failure(.noQueueProvided)
      }
      guard let jobs = self.data[queue.name] else {
        return .success([Job]())
      }
      return .success(jobs.values.map { $0 })
    }

    public func store(_ job: Job, queue: QueueIdentity?) -> Result<Job, JobQueueError> {
      guard let queue = (queue ?? self.queue) else {
        return .failure(.noQueueProvided)
      }
      var jobs = self.data[queue.name, default: [Job.ID: Job]()]
      jobs[job.id] = job
      self.data[queue.name] = jobs
      self.changes.append(.stored(queue.name, job.id, job))
      return .success(job)
    }

    public func remove(_ id: Job.ID, queue: QueueIdentity?) -> Result<Job.ID, JobQueueError> {
      guard let queue = (queue ?? self.queue) else {
        return .failure(.noQueueProvided)
      }
      guard var jobs = self.data[queue.name] else {
        return .success(id)
      }
      guard let job = jobs[id] else {
        return .success(id)
      }
      jobs.removeValue(forKey: id)
      self.data[queue.name] = jobs
      self.changes.append(.removed(queue.name, job.id, job))
      return .success(id)
    }

    public func remove(_ job: Job, queue: QueueIdentity?) -> Result<Job, JobQueueError> {
      guard let queue = (queue ?? self.queue) else {
        return .failure(.noQueueProvided)
      }
      guard var jobs = self.data[queue.name] else {
        return .success(job)
      }
      guard jobs[job.id] != nil else {
        return .success(job)
      }
      jobs.removeValue(forKey: job.id)
      self.data[queue.name] = jobs
      self.changes.append(.removed(queue.name, job.id, job))
      return .success(job)
    }

    public func removeAll(queue: QueueIdentity?) -> Result<Void, JobQueueError> {
      guard let queue = (queue ?? self.queue) else {
        return .failure(.noQueueProvided)
      }
      guard self.data[queue.name] != nil else {
        return .success(())
      }
      self.data.removeValue(forKey: queue.name)
      self.changes.append(.removedAll(queue.name))
      return .success(())
    }
  }
}
