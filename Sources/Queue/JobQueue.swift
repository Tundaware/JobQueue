///
///  Created by George Cox on 1/22/20.
///

import Foundation
import ReactiveSwift
#if SWIFT_PACKAGE
import JobQueueCore
#endif

public enum JobQueueError: Error {
  case jobNotFound(JobID)
}

public enum JobQueueEvent {
  case resumed
  case suspended
  case added(JobDetails)
  case updated(JobDetails)
  case removed(JobDetails)
  case registeredProcessor(JobName, concurrency: Int)
  case updatedStatus(JobDetails)
  case updatedProgress(JobDetails)
  case beganProcessing(JobDetails)
  case cancelledProcessing(JobDetails?, JobCancellationReason)
  case failedProcessing(JobDetails, Error)
  case finishedProcessing(JobDetails)
}

public final class JobQueue: JobQueueProtocol {
  public let name: String

  private let _isActive = MutableProperty(false)
  /// When `true`, the queue is active and can process jobs.
  /// When `false`, the queue is suspended, will not synchronize, and will not process jobs
  public let isActive: Property<Bool>

  private let _isSynchronizing = MutableProperty(false)
  private let isSynchronizing: Property<Bool>
  private let _isSynchronizePending = MutableProperty(false)
  private let isSynchronizePending: Property<Bool>

  private let _events = Signal<JobQueueEvent, Never>.pipe()
  /// An observable stream of events produced by the queue
  public let events: Signal<JobQueueEvent, Never>

  private let shouldSynchronize = Signal<Void, Never>.pipe()
  internal let schedulers: JobQueueSchedulers
  private let storage: JobStorage
  private let processors = JobQueueProcessors()
  private let sorter: JobSorter
  private let delayStrategy: JobQueueDelayStrategy
  private let logger: Logger

  private var disposables = CompositeDisposable()

  public init(
    name: String,
    schedulers: JobQueueSchedulers,
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
public extension JobQueue {
  /**
   Resumes the queue.

   This will set the `isActive` property to `true`. This will eventually trigger synchronization.

   - Returns: A `SignalProducer<Bool, Error>`
   The producer echoes the resulting `isActive` value or, if something went wrong,
   an `Error`.
   */
  func resume() -> SignalProducer<Bool, Error> {
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
  func suspend() -> SignalProducer<Bool, Error> {
    self.change(active: false)
      .on(value: {
        guard !$0 else {
          return
        }
        self.logger.trace("Queue (\(self.name)) suspended")
        self._events.input.send(value: .suspended)
      })
  }

  private func change(active: Bool) -> SignalProducer<Bool, Error> {
    return SignalProducer { o, lt in
      self._isActive.swap(active)
      o.send(value: self.isActive.value)
      o.sendCompleted()
    }
  }
}

// Job access
public extension JobQueue {
  func transaction<T>(synchronize: Bool = false, _ closure: @escaping (JobStorageTransaction) throws -> T) -> SignalProducer<T, Error> {
    return self.storage.transaction(queue: self, closure)
      .on(completed: {
        if synchronize {
          self.scheduleSynchronization()
        }
      })
  }

  func set(_ id: JobID, status: JobStatus) -> SignalProducer<JobDetails, Error> {
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

  func set(_ job: JobDetails, status: JobStatus) -> SignalProducer<JobDetails, Error> {
    guard job.status != status else {
      return SignalProducer(value: job)
    }
    return self.set(job.id, status: status)
      .on(completed: {
        self._events.input.send(value: .updatedStatus(job))
      })
  }

  /**
   Fetch one job of type `AnyJob`

   - Parameter id: the id of the job to get
   - Returns: A `SignalProducer<AnyJob, Error>` that sends the job or, if not found, an error
   */
  func get(_ id: JobID) -> SignalProducer<JobDetails, Error> {
    self.transaction { try $0.get(id).get() }
  }

  /**
   Get all jobs in the queue

   - Returns: A `SignalProducer<[AnyJob], Error>` that sends the jobs in the queue or
   any error from the underlying storage provider
   */
  func getAll() -> SignalProducer<[JobDetails], Error> {
    self.transaction { try $0.getAll().get() }
  }

  /**
   Stores one job, of type `AnyJob`

   If the job is stored successfully. This will eventually trigger synchronization.

   - Parameter job: the job to store
   - Returns: A `SignalProducer<AnyJob, Error>` that echoes the job or any error
   from the underlying storage provider
   */
  func store(_ job: JobDetails, synchronize: Bool = true) -> SignalProducer<JobDetails, Error> {
    self.transaction(synchronize: synchronize) { try $0.store(job).get() }
  }

  /**
   Remove one job by id

   Removes a job from persistance. If processing, the job will be cancelled with
   a `JobCancellationReason` of `removed`.

   - Parameter id: the id of the job to remove
   - Returns: A `SignalProducer<JobID, Error>` that sends the id or any error
     from the underlying storage provider
   */
  func remove(_ id: JobID, synchronize: Bool = true) -> SignalProducer<JobID, Error> {
    self.transaction(synchronize: synchronize) { try $0.remove(id).get() }
  }

  /**
   Remove one job

   Removes a job from persistance. If processing, the job will be cancelled with
   a `JobCancellationReason` of `removed`.

   - Note: Although the `SignalProducer` will send the job if it is removed successfully,
   the job will no longer be persisted and the job should be used with that in mind.

   - Parameter job: the job to remove
   - Returns: A `SignalProducer<AnyJob, Error>` that sends the job or any error
   from the underlying storage provider
   */
  func remove(_ job: JobDetails, synchronize: Bool = true) -> SignalProducer<JobDetails, Error> {
    self.transaction(synchronize: synchronize) { try $0.remove(job).get() }
  }
}

public extension JobQueue {
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
  func register<T>(_ type: T.Type, concurrency: Int = 1) where T: Job {
    self.processors.configurations[T.typeName] =
      JobProcessorConfiguration(type, concurrency: concurrency)

    self._events.input.send(value: .registeredProcessor(T.typeName, concurrency: concurrency))
  }
}

private extension JobQueue {
  func scheduleSynchronization() {
    guard !self.isSynchronizePending.value else {
      return
    }
    self._isSynchronizePending.swap(true)
  }

  func configureDelayTimer(for jobs: [JobDetails]) {}

  /**
   Synchronize the queue

   This inspects the queue's jobs, determines which jobs should be active, and applies
   the necessary mutations to make that happen.

   This happens on the `schedulers.synchronize` `Scheduler`.

   - Parameter jobs: all jobs in the queue
   */
  func synchronize(jobs: [JobDetails]) -> SignalProducer<Void, Error> {
    return SignalProducer { o, lt in
      let sortedJobs = self.sorter.sort(jobs: jobs)
      let jobsToProcessByName = self.processable(jobs: sortedJobs)
      let jobIDsToProcess = jobsToProcessByName.jobIDs
      let processorsToCancelByID = self.processors.activeProcessorsByID(excluding: jobIDsToProcess)

      self.delayStrategy.update(queue: self, jobs: sortedJobs.delayedJobs)

      // Apply cancellations
      processorsToCancelByID.forEach { kvp in
        guard let job = sortedJobs.first(where: { $0.id == kvp.key }) else {
          kvp.value.cancel(reason: .removed)
          self._events.input.send(value: .cancelledProcessing(nil, .removed))
          return
        }
        kvp.value.cancel(reason: .statusChangedToWaiting)
        self._events.input.send(value: .cancelledProcessing(job, .statusChangedToWaiting))
      }

      // Cleanup processors
      self.processors.remove(processors: processorsToCancelByID.keys.map { $0 })

      // Process jobs to process
      lt += SignalProducer(
        jobsToProcessByName.reduce(into: [JobDetails]()) { acc, kvp in
          acc.append(contentsOf: kvp.value.filter { !self.processors.isProcessing(job: $0) })
        }
      ).flatMap(.concat) {
        self.beginProcessing(job: $0)
      }.startWithCompleted {
        o.send(value: ())
        o.sendCompleted()
      }
    }
    .start(on: self.schedulers.synchronize)
  }

  /**
   Reduces a list of jobs down to only the jobs that should be currently processing
   in the form of a map from job name to jobs.

   - Parameter jobs: the list of jobs to reduce
   */
  func processable(jobs: [JobDetails]) -> [JobName: [JobDetails]] {
    return jobs.reduce(into: [JobName: [JobDetails]]()) { acc, job in
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
      var nextJobs = acc[job.type, default: [JobDetails]()]
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
  func beginProcessing(job: JobDetails) -> SignalProducer<JobDetails, Error> {
    return
      self.get(job.id)
        .filter {
          self.logger.trace("Queue \(self.name) beginProcessing job \(($0.id, $0.status))")
          switch $0.status {
          case .active, .waiting:
            return true
          default:
            return false
          }
        }
        .flatMap(.concat) { self.set($0, status: .active) }
        .on(
          value: { _job in
            guard let processor = self.processors.activeProcessor(for: _job) else {
              return
            }
            processor.process(details: _job, queue: self) { result in
              self.schedulers.synchronize.schedule {
                switch result {
                case .success:
                  self.logger.trace("Queue (\(self.name)) job \(_job.id) processed")
                  self.set(_job.id, status: .completed(at: Date()))
                    .on(
                      value: {
                        self.processors.remove(processors: [$0.id])
                        self.logger.trace("Queue (\(self.name)) removed processor for job \($0.id)")
                        self._events.input.send(value: .finishedProcessing($0))
                      }
                    )
                    .start()
                case .failure(let error):
                  self.logger.trace("Queue (\(self.name)) job \(_job.id) failed processing \(error.localizedDescription)")
                  self.set(_job.id, status: .failed(at: Date(), message: error.localizedDescription))
                    .on(
                      value: {
                        self.processors.remove(processors: [$0.id])
                        self.logger.trace("Queue (\(self.name)) removed processor for job \($0.id)")
                        self._events.input.send(value: .failedProcessing($0, error))
                      }
                    )
                    .start()
                }
                self.logger.trace("Queue (\(self.name)) began processing job \(_job.id)")
                self._events.input.send(value: .beganProcessing(job))
              }
            }
          }
        )
  }
}
