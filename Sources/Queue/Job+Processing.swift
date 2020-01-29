///
///  Created by George Cox on 1/27/20.
///

import Foundation
import ReactiveSwift

#if SWIFT_PACKAGE
import JobQueueCore
#endif

extension JobProcessor {
  public func process(job: Job, queue: JobQueueProtocol, done: @escaping JobCompletion) {
    do {
      let payload = try Self.deserialize(job.payload)
      self.process(job: job, payload: payload, queue: queue, done: done)
    } catch {
      done(.failure(.payloadDeserialization(job.id, queue.name, error)))
    }
  }
}

extension JobProcessor {
  public static var typeName: JobName { String(describing: Self.self) }
}

open class DefaultJobProcessor<T>: JobProcessor, Equatable where T: Codable {
  public typealias Payload = T

  private let _cancelled = MutableProperty<JobCancellationReason?>(nil)
  public private(set) lazy var cancelled = Property(capturing: _cancelled)

  public required init() {}

  /**
   Starts processing a job

   This is an **abstract** implementation meant to be overridden by sub-classes.
   Sub-classes should not invoke it using `super`.

   - Parameters:
     - job: the job to process
     - queue: the queue the job belongs to
     - done: the completion callback.
   */
  open func process(job: Job, payload: Payload, queue: JobQueueProtocol, done: @escaping JobCompletion) {
    done(.failure(.abstractFunction))
  }

  /**
   Cancel processing the job

   This implementation updates the backing property for the `cancelled` property
   so the `process` implementation can observe the change and cancel the job cleanly.

   - Parameter reason: the reason the job is being cancelled
   */
  public func cancel(reason: JobCancellationReason) {
    self._cancelled.swap(reason)
  }

  public static func == (lhs: DefaultJobProcessor<T>, rhs: DefaultJobProcessor<T>) -> Bool {
    return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
  }
}
