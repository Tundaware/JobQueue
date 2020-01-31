///
///  Created by George Cox on 1/27/20.
///

import Foundation
import ReactiveSwift

public protocol JobStorageTransaction {
  func get(_ id: Job.ID, queue: QueueIdentity?) -> Result<Job, JobQueueError>
  func getAll(queue: QueueIdentity?) -> Result<[Job], JobQueueError>

  func store(_ job: Job, queue: QueueIdentity?) -> Result<Job, JobQueueError>

  func remove(_ id: Job.ID, queue: QueueIdentity?) -> Result<Job.ID, JobQueueError>
  func remove(_ job: Job, queue: QueueIdentity?) -> Result<Job, JobQueueError>
  func removeAll(queue: QueueIdentity?) -> Result<Void, JobQueueError>
}

public extension JobStorageTransaction {
  func get(_ id: Job.ID) -> Result<Job, JobQueueError> {
    self.get(id, queue: nil)
  }
  func getAll() -> Result<[Job], JobQueueError> {
    self.getAll(queue: nil)
  }
  func store(_ job: Job) -> Result<Job, JobQueueError> {
    self.store(job, queue: nil)
  }

  func remove(_ id: Job.ID) -> Result<Job.ID, JobQueueError> {
    self.remove(id, queue: nil)
  }
  func remove(_ job: Job) -> Result<Job, JobQueueError> {
    self.remove(job, queue: nil)
  }

  func removeAll() -> Result<Void, JobQueueError> {
    self.removeAll(queue: nil)
  }
}
