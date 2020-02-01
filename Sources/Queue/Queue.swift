///
///  Created by George Cox on 1/22/20.
///

import Foundation
import ReactiveSwift
#if SWIFT_PACKAGE
import JobQueueCore
#endif

public protocol QueueInteraction {
  func update<T, Payload>(
    _ processorType: T.Type,
    id: Job.ID,
    synchronize: Bool,
    modifyPayload: @escaping (Payload) -> Payload
  ) -> SignalProducer<Job, JobQueueError> where T: Job.Processor<Payload>
}

public enum QueueEvent {
  case resumed
  case suspended
  case added(Job)
  case updated(Job)
  case removed(Job)
  case registeredProcessor(Job.TypeName, concurrency: Int)
  case updatedStatus(Job)
  case updatedProgress(Job)
  case beganProcessing(Job)
  case cancelledProcessing(Job?, JobCancellationReason)
  case failedProcessing(Job, Error)
  case finishedProcessing(Job)
}

public final class Queue: QueueIdentity {
  public let name: String

  private let _isActive = MutableProperty(false)
  /// When `true`, the queue is active and can process jobs.
  /// When `false`, the queue is suspended, will not synchronize, and will not process jobs
  public let isActive: Property<Bool>

  private let _isSynchronizing = MutableProperty(false)
  private let isSynchronizing: Property<Bool>
  private let _isSynchronizePending = MutableProperty(false)
  private let isSynchronizePending: Property<Bool>

  private let _events = Signal<QueueEvent, Never>.pipe()
  /// An observable stream of events produced by the queue
  public let events: Signal<QueueEvent, Never>

  private let shouldSynchronize = Signal<Void, Never>.pipe()
  internal let schedulers: Schedulers
  private let storage: JobStorage
  private let processors = Processors()
  private let sorter: JobSorter
  private let delayStrategy: JobQueueDelayStrategy
  private let logger: Logger

  private var disposables = CompositeDisposable()

  public init(
    name: String,
    schedulers: Schedulers,
    storage: JobStorage,
    sorter: JobSorter = DefaultJobSorter(),
    delayStrategy: JobQueueDelayStrategy = JobQueueDelayPollingStrategy(),
    logger: Logger = ConsoleLogger()
  ) {
    self.name = name
    self.schedulers = schedulers
    self.storage = storage
    self.sorter = sorter
    self.delayStrategy = delayStrategy
    self.isActive = Property(capturing: self._isActive)
    self.isSynchronizing = Property(capturing: self._isSynchronizing)
    self.isSynchronizePending = Property(capturing: self._isSynchronizePending)
    self.events = self._events.output
    self.logger = logger

    /**
     Monitor `shouldSynchronize`, throttling for noise, while the queue is suspended,
     and while the queue is synchronizing.

     Once those conditions are met, the `_isSynchronizing` property is set to `true`,
     which has the side effect of triggering synchronization.
     */
    self.disposables += self.isSynchronizePending.producer
      .filter { $0 }
      .throttle(0.5, on: self.schedulers.synchronizePending)
      .throttle(while: self.isActive.map { !$0 }, on: self.schedulers.synchronizePending)
      .throttle(while: self.isSynchronizing.map { $0 }, on: self.schedulers.synchronizePending)
      .map { _ in }
      .on(value: {
        logger.trace("Queue (\(name)) will set _isSynchronizing to true")
        self._isSynchronizePending.value = false
        self._isSynchronizing.value = true
        logger.trace("Queue (\(name)) did set _isSynchronizing to true")
      })
      .start()

    /**
     Monitor `isSynchronizing`
     When it becomes true, the queue's jobs are fetched, the queue is synchronized
     using those jobs, and the `_isSynchronizing` property is then set back to `false`.
     */
    self.disposables += self.isSynchronizing.producer
      .skip(first: 1)
      .skipRepeats()
      .filter { $0 }
      .map { _ in
        logger.trace("Queue (\(name)) isSynchronizing is true, will get all jobs and synchronize...")
      }
      .flatMap(.concat) { self.getAll() }
      .on(
        value: { jobs in
          logger.trace("Queue (\(name)) jobs to synchronize: \(jobs.map { ($0.id, $0.status) })")
          logger.trace("Queue (\(name)) did get all jobs, will synchronize")
        }
      )
      .flatMap(.concat) { self.synchronize(jobs: $0) }
      .on(value: {
        logger.trace("Queue (\(name)) did synchronize, will set _isSynchronizing to false")
        self._isSynchronizing.value = false
        logger.trace("Queue (\(name)) did set _isSynchronizing to false")
      })
      .start()

    logger.info("Queue (\(name)) initialized")
  }

  deinit {
    disposables.dispose()
  }
}

/// `isActive` mutation functions
public extension Queue {
  /**
   Resumes the queue.

   This will set the `isActive` property to `true`. This will eventually trigger synchronization.

   - Returns: A `SignalProducer<Bool, Error>`
   The producer echoes the resulting `isActive` value or, if something went wrong,
   an `Error`.
   */
  func resume() -> SignalProducer<Bool, JobQueueError> {
    self.change(active: true)
      .on(value: {
        guard $0 else {
          return
        }
        self.logger.trace("Queue (\(self.name)) resumed")
        self._events.input.send(value: .resumed)
      })
  }

  /**
   Suspends the queue.

   This will set the `isActive` property to `false` and, as soon as possible, any
   processing jobs will be cancelled with a `JobCancellationReason` of `queueSuspended`.

   - Note: Synchronization does not run while the queue is suspended.

   - Returns: A `SignalProducer<Bool, Error>`
   The producer echoes the resulting `isActive` value or, if something went wrong,
   an `Error`.
   */
  func suspend() -> SignalProducer<Bool, JobQueueError> {
    self.change(active: false)
      .on(value: {
        guard !$0 else {
          return
        }
        self.logger.trace("Queue (\(self.name)) suspended")
        self._events.input.send(value: .suspended)
      })
  }

  private func change(active: Bool) -> SignalProducer<Bool, JobQueueError> {
    return SignalProducer { o, lt in
      self._isActive.swap(active)
      o.send(value: self.isActive.value)
      o.sendCompleted()
    }
  }
}

// Job access
public extension Queue {
  func transaction<T>(synchronize: Bool = false, _ closure: @escaping (JobStorageTransaction) throws -> T) -> SignalProducer<T, JobQueueError> {
    return self.storage.transaction(queue: self, closure)
      .on(completed: {
        if synchronize {
          self.scheduleSynchronization()
        }
      })
  }

  func set(_ id: Job.ID, status: Job.Status) -> SignalProducer<Job, JobQueueError> {
    return self.transaction(synchronize: true) {
      var job = (try $0.get(id).get())
      guard job.status != status else {
        return job
      }
      job.status = status
      self.logger.trace("QUEUE (\(self.name)) storing job with new status of \(job.status)")
      return try $0.store(job).get()
    }.on(completed: {
      self.logger.trace("QUEUE (\(self.name)) set job \(id) status to \(status)")
    })
  }

  func set(_ job: Job, status: Job.Status) -> SignalProducer<Job, JobQueueError> {
    guard job.status != status else {
      return SignalProducer(value: job)
    }
    return self.set(job.id, status: status)
      .on(completed: {
        self._events.input.send(value: .updatedStatus(job))
      })
  }

  /**
   Fetch one job

   - Parameter id: the id of the job to get
   - Returns: A `SignalProducer<Job, Error>` that sends the job or, if not found, an error
   */
  func get(_ id: Job.ID) -> SignalProducer<Job, JobQueueError> {
    self.transaction { try $0.get(id).get() }
  }

  /**
   Get all jobs in the queue

   - Returns: A `SignalProducer<[Job], Error>` that sends the jobs in the queue or
   any error from the underlying storage provider
   */
  func getAll() -> SignalProducer<[Job], JobQueueError> {
    self.transaction { try $0.getAll().get() }
  }

  /**
   Stores one job

   If the job is stored successfully. This will eventually trigger synchronization.

   - Parameter job: the job to store
   - Returns: A `SignalProducer<Job, Error>` that echoes the job or any error
   from the underlying storage provider
   */
  func store(_ job: Job, synchronize: Bool = true) -> SignalProducer<Job, JobQueueError> {
    self.transaction(synchronize: synchronize) { try $0.store(job).get() }
  }

  /**
   Remove one job by id

   Removes a job from persistance. If processing, the job will be cancelled with
   a `JobCancellationReason` of `removed`.

   - Parameter id: the id of the job to remove
   - Returns: A `SignalProducer<Job.ID, Error>` that sends the id or any error
     from the underlying storage provider
   */
  func remove(_ id: Job.ID, synchronize: Bool = true) -> SignalProducer<Job.ID, JobQueueError> {
    self.transaction(synchronize: synchronize) { try $0.remove(id).get() }
  }

  /**
   Remove one job

   Removes a job from persistance. If processing, the job will be cancelled with
   a `JobCancellationReason` of `removed`.

   - Note: Although the `SignalProducer` will send the job if it is removed successfully,
   the job will no longer be persisted and the job should be used with that in mind.

   - Parameter job: the job to remove
   - Returns: A `SignalProducer<Job, Error>` that sends the job or any error
   from the underlying storage provider
   */
  func remove(_ job: Job, synchronize: Bool = true) -> SignalProducer<Job, JobQueueError> {
    self.transaction(synchronize: synchronize) { try $0.remove(job).get() }
  }
}

extension Queue: QueueInteraction {
  public func update<T, Payload>(
    _ processorType: T.Type,
    id: Job.ID,
    synchronize: Bool = true,
    modifyPayload: @escaping (Payload) -> Payload
  ) -> SignalProducer<Job, JobQueueError> where T: Job.Processor<Payload> {
    return self.get(id).flatMap(.concat) { (job: Job) -> SignalProducer<Job, JobQueueError> in
      do {
        let newJob = try Job(
          T.self,
          job: job,
          payload: modifyPayload(try T.deserialize(job.payload))
        )
        return self.store(newJob, synchronize: synchronize)
      } catch {
        return SignalProducer<Job, JobQueueError>(error: .from(error))
      }
    }
  }
}

public extension Queue {
  /**
   Registers a `JobProcessor` type with the queue

   Each `JobProcessor` processes a specific type of `Job`, `JobProcessor.JobType`.

   Each `JobProcessor` instance processes one job at a time.

   There can be up to `concurrency` instances of the registered `JobProcessor`,
   which means up to `concurrency` `JobProcessor.JobType` jobs can be processed
   concurrently.

   - Parameters:
     - type: the `JobProcessor`'s type
     - concurrency: the maximum number of instances of this `JobProcessor` that can
     simultaneously process jobs. defaults to `1`.
   */
  func register<T, Payload>(_ type: T.Type, concurrency: Int = 1) where T: Job.Processor<Payload> {
    self.processors.configurations[T.jobType] = .init(
      type,
      concurrency: concurrency,
      logger: self.logger
    )

    self._events.input.send(value: .registeredProcessor(T.jobType, concurrency: concurrency))
  }
}

private extension Queue {
  func scheduleSynchronization() {
    guard !self.isSynchronizePending.value else {
      return
    }
    self._isSynchronizePending.swap(true)
  }

  func configureDelayTimer(for jobs: [Job]) {}

  /**
   Synchronize the queue

   This inspects the queue's jobs, determines which jobs should be active, and applies
   the necessary mutations to make that happen.

   This happens on the `schedulers.synchronize` `Scheduler`.

   - Parameter jobs: all jobs in the queue
   */
  func synchronize(jobs: [Job]) -> SignalProducer<Void, JobQueueError> {
    return SignalProducer { o, lt in
      let sortedJobs = self.sorter.sort(jobs: jobs)
      let jobsToProcessByName = self.processable(jobs: sortedJobs)
      let jobIDsToProcess = jobsToProcessByName.jobIDs
      let processorsToCancelByID = self.processors.activeProcessorsByID(excluding: jobIDsToProcess)

      self.delayStrategy.update(queue: self, jobs: sortedJobs.delayedJobs)

      lt += SignalProducer(processorsToCancelByID)
        .flatMap(.concat) { kvp -> SignalProducer<Void, JobQueueError> in
          // If there is no job in the queue with the job id associated with the
          // processor, cancel the processor with `.removed` as the reason.
          // This means the job is no longer with us and processing should stop.
          guard let job = sortedJobs.first(where: { $0.id == kvp.key }) else {
            return kvp.value.change(status: .cancelled(.removed))
              .on(
                value: { _ in
                  self._events.input.send(value: .cancelledProcessing(nil, .removed))
                }
              ).map { _ in }
          }
          // Determine the cancellation reason based on the job's current status
          // e.g. If the job's status has been set to `.paused`, the cancellation
          // reason should reflect that.
          // If no cancellation reason, it means the processor is already in some
          // sort of finished state (completed, failed) so we just send void.
          guard let cancellationReason = self.getCancellationReason(given: job.status) else {
            return SignalProducer<Void, JobQueueError>(value: ())
          }
          // Cancel the processor using the determined cancellation reason
          return kvp.value.change(status: .cancelled(cancellationReason))
            .on(
              value: { _ in
                self._events.input.send(value: .cancelledProcessing(job, cancellationReason))
              }
            )
            .map { _ in }
        }
        .collect() // Collect all the Void results, we don't care about them
        .on(value: { _ in
          // Remove the cancelled processors
          self.processors.remove(processors: processorsToCancelByID.keys.map { $0 })
        })
        .then(
          SignalProducer(
            jobsToProcessByName.reduce(into: [Job]()) { acc, kvp in
              acc.append(contentsOf: kvp.value.filter { !self.processors.isProcessing(job: $0) })
            }
          ).flatMap(.concat) {
            self.beginProcessing(job: $0)
          }
        )
        .startWithCompleted {
          o.send(value: ())
          o.sendCompleted()
        }
    }
    .start(on: self.schedulers.synchronize)
  }

  func getCancellationReason(given status: Job.Status) -> JobCancellationReason? {
    switch status {
    case .active:
      return .statusChangedToWaiting
    case .paused:
      return .statusChangedToPaused
    case .delayed:
      return .statusChangedToDelayed
    case .waiting:
      return .statusChangedToWaiting
    default:
      // TODO: It may be possible for .completed/.failed statuses to be encountered
      // here, which isn't good. We need to either prevent that or handle
      // it in a graceful manner. Theoretically, any completed/failed job
      // should have already been removed when the processor indicated it
      // completed/failed.
      return nil
    }
  }

  /**
   Reduces a list of jobs down to only the jobs that should be currently processing
   in the form of a map from job name to jobs.

   - Parameter jobs: the list of jobs to reduce
   */
  func processable(jobs: [Job]) -> [Job.TypeName: [Job]] {
    return jobs.reduce(into: [Job.TypeName: [Job]]()) { acc, job in
      guard let configuration = self.processors.configurations[job.type] else {
        return
      }
      guard configuration.concurrency > 0 else {
        return
      }
      switch job.status {
      case .completed, .paused, .failed, .delayed:
        return
      default:
        break
      }
      var nextJobs = acc[job.type, default: [Job]()]
      guard nextJobs.count < configuration.concurrency else {
        return
      }
      acc[job.type] = {
        nextJobs.append(job)
        return nextJobs
      }()
    }
  }

  /**
   Starts processing a job

   Triggers a `.beganProcessing` event immediately, then either a `.finishedProcessing`
   or `.failedProcessing` event when the job completes.

   - Parameter job: the job to process
   */
  func beginProcessing(job: Job) -> SignalProducer<Job, JobQueueError> {
    return
      self.get(job.id)
        /// Only jobs with a status of `active` or `waiting` can be active.
        /// `active` jobs must be considererd since active jobs prior to the application
        /// terminating will need to be restarted. They are ignored if an existing
        /// processor is found for them in a subsequent step.
        .filter {
          self.logger.trace("Queue \(self.name) beginProcessing job \(($0.id, $0.status))")
          switch $0.status {
          case .active, .waiting:
            return true
          default:
            return false
          }
        }
        /// Set the status to active. `set(:status:)` is a no-op if the status is
        /// already active.
        .flatMap(.concat) { self.set($0, status: .active) }
        /// Start processing if we have a processor for the job and it is not already
        /// active
        .flatMap(.concat) { _job -> SignalProducer<Job, JobQueueError> in
          guard let processor = self.processors.activeProcessor(for: _job) else {
            return SignalProducer<Job, JobQueueError>(value: _job)
          }
          /// Skip if the processor is already active
          guard processor.status.value != .active(job: _job, queue: self) else {
            return SignalProducer<Job, JobQueueError>(value: _job)
          }
          /// Start monitoring the processor's status for `completed` and `failed`.
          /// When those statuses are found, update the job's status, then report
          /// the event.
          /// **NOTE**: While much of this could be moved to the `JobProcessor`
          /// itself, we'd still need to pipe the `finished/failedProcessing` events.
          /// Probably not worth the effort or added complexity.
          self.disposables += processor.status.producer
            .flatMap(.concat) { processorStatus -> SignalProducer<Void, JobQueueError> in
              switch processorStatus {
              case .completed(let date):
                return self.set(_job.id, status: .completed(at: date))
                  .on(
                    value: {
                      self.logger.trace("Queue (\(self.name)) finished processing job \($0.id)")
                      self._events.input.send(value: .finishedProcessing($0))
                    }
                  )
                  .map { _ in }
              case .failed(let date, let error):
                return self.set(_job.id, status: .failed(at: date, message: error.localizedDescription))
                  .on(
                    value: {
                      self.logger.trace("Queue (\(self.name)) failed processing job \($0.id)")
                      self._events.input.send(value: .failedProcessing($0, error))
                    }
                  )
                  .map { _ in }
              default: return SignalProducer<Void, JobQueueError>(value: ())
              }
            }.start()

          /// Activate the processor
          return processor
            .change(status: .active(job: job, queue: self))
            .map { _ in _job }
        }
  }
}
