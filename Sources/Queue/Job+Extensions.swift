///
///  Created by George Cox on 1/30/20.
///

import Foundation
#if SWIFT_PACKAGE
import JobQueueCore
#endif

extension Job {
  /// Initialize a job with a typed payload inferred from a specific processor type
  ///
  /// - Parameters:
  ///   - type: The Job's processor type
  ///   - id: The job's id
  ///   - queueName: The name of the queue
  ///   - payload: The typed payload
  ///   - queuedAt: The queued at date
  ///   - status: The job's initial status
  ///   - schedule: The job's schedule (not supported yet)
  ///   - order: The job's manual execution order
  ///   - progress: The job's initial progress
  public init<T, Payload>(
    _ type: T.Type,
    id: JobID,
    queueName: JobQueueName,
    payload: Payload,
    queuedAt: Date = Date(),
    status: JobStatus = .waiting,
    schedule: JobSchedule? = nil,
    order: Float? = nil,
    progress: Float? = nil
  ) throws where T: JobProcessor<Payload> {
    self.init(
      type: T.jobType,
      id: id,
      queueName: queueName,
      payload: try T.serialize(payload),
      queuedAt: queuedAt,
      status: status,
      schedule: schedule,
      order: order,
      progress: progress
    )
  }
}
