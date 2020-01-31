///
///  Created by George Cox on 1/27/20.
///

import Foundation
import ReactiveSwift

#if SWIFT_PACKAGE
import JobQueueCore
#endif

// Internal JobProcessor contract
protocol AnyJobProcessor: class {
  static var jobType: JobType { get }

  var status: Property<JobProcessorStatus> { get }

  init(logger: Logger)

  func change(status: JobProcessorStatus) -> SignalProducer<Void, JobQueueError>
  func process(job: Job, queue: JobQueue)
}

public enum JobProcessorStatus: CustomStringConvertible, Equatable {
  /// The processor has been created and has not been acted on
  case new
  /// The processor is actively processing a job
  case active(job: Job, queue: JobQueue)
  /// The processor is cancelled for some reason
  case cancelled(JobCancellationReason)
  /// The processor has completed. This status is set by sub-classes
  case completed(at: Date)
  /// The processor has failed. This status is set by sub-classes.
  case failed(at: Date, error: JobQueueError)

  public var description: String {
    switch self {
    case .new: return "new"
    case .active: return "active"
    case .cancelled: return "cancelled"
    case .completed: return "completed"
    case .failed: return "failed"
    }
  }

  /// Equatable implementation using simple equality, ignoring any associated values
  ///
  /// - Parameters:
  ///   - lhs: first status to consider
  ///   - rhs: second status to consider
  public static func == (lhs: JobProcessorStatus, rhs: JobProcessorStatus) -> Bool {
    switch lhs {
    case .new:
      switch rhs {
      case .new: return true
      default: return false
      }
    case .active:
      switch rhs {
      case .active: return true
      default: return false
      }
    case .cancelled:
      switch rhs {
      case .cancelled: return true
      default: return false
      }
    case .completed:
      switch rhs {
      case .completed: return true
      default: return false
      }
    case .failed:
      switch rhs {
      case .failed: return true
      default: return false
      }
    }
  }
}

/// The base processor that all processors should sub-class
open class JobProcessor<Payload> where Payload: Codable {
  open class var jobType: JobType {
    return String(describing: Self.self)
  }
  
  private let scheduler = QueueScheduler()

  private let _status = MutableProperty<JobProcessorStatus>(.new)
  public private(set) lazy var status = Property(capturing: _status)

  public let logger: Logger

  public required init(
    logger: Logger = ConsoleLogger()
  ) {
    self.logger = logger

    /// Observe the processor's own status and invoke the `process` and `cancel`
    /// functions when appropriate
    self.status.producer
      .skipRepeats()
      .on(
        value: {
          logger.trace("JobProcessor (\(Self.jobType)): Observed New Status -> \($0)")
          switch $0 {
          case .active(let job, let queue):
            self.process(job: job, queue: queue)
          case .cancelled(let reason):
            self.cancel(reason: reason)
          default:
            break
          }
        }
      )
      .start()
  }

  /// Invoked after a processor's status is changed to `.active(job:queue:)`
  ///
  /// This function **should not** be called directly
  ///
  /// - Parameters:
  ///   - job: The job to process
  ///   - payload: The job's deserialized payload
  ///   - queue: The queue the job is in. Use carefully. Do not use it to modify
  ///            the job being processed, that's what the `change(status:)` function
  ///            is for.
  open func process(job: Job, payload: Payload, queue: JobQueue) {
    self.change(status:
      .failed(
        at: Date(),
        error: .abstractFunction("process(job:payload:queue:) is abstract and must be implemented by JobProcessor sub-classes")
      )
    )
    .start()
  }

  /// Invoked after a processor's status is changed to `.cancelled(reason:)`
  ///
  /// This function **should not** be called directly
  ///
  /// - Parameter reason: The reason for cancellation. This should be used if the
  ///                     job requires special handling when cancelled.
  ///                     e.g. Delete a partially downloaded file
  open func cancel(reason: JobCancellationReason) {
  }
}

extension JobProcessor: AnyJobProcessor {
  /// Changes the status of the job processor
  ///
  /// The status is only changed if it is permitted given the current status
  ///
  /// - Parameter status: the proposed new status
  public func change(status: JobProcessorStatus) -> SignalProducer<Void, JobQueueError> {
    return SignalProducer { o, lt in
      let currentStatus = self.status.value
      var nextStatus: JobProcessorStatus?

      switch status {
      case .new:
        // The processor starts as `new`, it should never be considered `new`
        // after it's status has changed to anything else.
        break
      case .active:
        switch currentStatus {
        case .new:
          nextStatus = status
        default:
          break
        }
      case .cancelled:
        switch currentStatus {
        case .new, .active:
          nextStatus = status
        default:
          break
        }
      case .completed, .failed:
        switch currentStatus {
        case .active:
          nextStatus = status
        default:
          break
        }
      }
      if let nextStatus = nextStatus {
        self._status.swap(nextStatus)
      }
      o.send(value: ())
      o.sendCompleted()
    }.start(on: self.scheduler)
  }
}

extension JobProcessor: Equatable {
  public static func == (lhs: JobProcessor<Payload>, rhs: JobProcessor<Payload>) -> Bool {
    return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
  }
}

extension JobProcessor {
  /// Default implementation that uses the JSONEncoder
  ///
  /// - Parameter payload: the payload
  public static func serialize(_ payload: Payload) throws -> [UInt8] {
    return .init(try JSONEncoder().encode([payload]))
  }

  /// Default implementation that uses the JSONDecoder
  ///
  /// - Parameter rawPayload: the raw payload bytes
  public static func deserialize(_ rawPayload: [UInt8]) throws -> Payload {
    return try JSONDecoder().decode([Payload].self, from: .init(rawPayload)).first!
  }
}

extension JobProcessor {
  /// Ensures the raw payload can be deserialized to the typed payload. If successful,
  /// invoke the open `process` function. Otherwise, change the processor's status
  /// to failed.
  ///
  /// - Parameters:
  ///   - job: the job to process
  ///   - queue: the queue the job is associated with
  func process(job: Job, queue: JobQueue) {
    do {
      let payload = try Self.deserialize(job.payload)
      self.process(job: job, payload: payload, queue: queue)
    } catch {
      self.change(
        status: .failed(
          at: Date(),
          error: .payloadDeserialization(job.id, queue.name, error)
        )
      ).start()
    }
  }
}
