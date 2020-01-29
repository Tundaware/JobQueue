///
///  Created by George Cox on 1/27/20.
///

import Foundation
import ReactiveSwift

public protocol JobStorageTransaction {
  func get(_ id: JobID, queue: JobQueueProtocol?) -> Result<Job, JobQueueError>
  func getAll(queue: JobQueueProtocol?) -> Result<[Job], JobQueueError>

  func store(_ job: Job, queue: JobQueueProtocol?) -> Result<Job, JobQueueError>

  func remove(_ id: JobID, queue: JobQueueProtocol?) -> Result<JobID, JobQueueError>
  func remove(_ job: Job, queue: JobQueueProtocol?) -> Result<Job, JobQueueError>
  func removeAll(queue: JobQueueProtocol?) -> Result<Void, JobQueueError>
}

public extension JobStorageTransaction {
  func get(_ id: JobID) -> Result<Job, JobQueueError> {
    self.get(id, queue: nil)
  }
  func getAll() -> Result<[Job], JobQueueError> {
    self.getAll(queue: nil)
  }
  func store(_ job: Job) -> Result<Job, JobQueueError> {
    self.store(job, queue: nil)
  }

  func remove(_ id: JobID) -> Result<JobID, JobQueueError> {
    self.remove(id, queue: nil)
  }
  func remove(_ job: Job) -> Result<Job, JobQueueError> {
    self.remove(job, queue: nil)
  }

  func removeAll() -> Result<Void, JobQueueError> {
    self.removeAll(queue: nil)
  }
}
