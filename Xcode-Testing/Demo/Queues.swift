///
///  Created by George Cox on 1/29/20.
///

import CoreData
import CouchbaseLiteSwift
import Foundation
import JobQueue
import NanoID
import ReactiveSwift

class TestProcessor: DefaultJobProcessor<String> {
  override class var typeName: JobName {
    return "Test"
  }

  override func process(job: Job, payload: Payload, queue: JobQueueProtocol, done: @escaping JobCompletion) {
    QueueScheduler().schedule(after: Date().addingTimeInterval(TimeInterval.random(in: 0.5...10))) {
      done(.success(()))
    }
  }
}

public class Queues {
  public static let shared = Queues()

  private let schedulers = JobQueueSchedulers()

  private var inMemoryQueue: JobQueue?

  private let coreDataStack = CoreDataStack()
  private var coreDataQueue: JobQueue?

  private var database: Database?
  private var couchbaseLiteQueue: JobQueue?

  public private(set) var queues = [JobQueueName: JobQueue]()

  init() {
    self.demoInMemoryQueue()
    self.demoCoreDataQueue()
    self.demoCouchbaseLiteQueue()
  }

  func demoInMemoryQueue() {
    self.inMemoryQueue = JobQueue(
      name: "InMemory Queue",
      schedulers: self.schedulers,
      storage: InMemoryStorage(scheduler: self.schedulers.storage)
    )
    guard let queue = self.inMemoryQueue else {
      return
    }
    self.demo(queue: queue)
  }

  func demoCoreDataQueue() {
    self.coreDataQueue = JobQueue(
      name: "CoreData Queue",
      schedulers: self.schedulers,
      storage: CoreDataStorage(
        createContext: self.coreDataStack.container.newBackgroundContext,
        rollback: self.coreDataStack.rollback(_:),
        commit: self.coreDataStack.commit(_:)
      )
    )
    guard let queue = self.coreDataQueue else {
      return
    }
    self.coreDataStack.load().startWithCompleted {
      self.demo(queue: queue)
    }
  }

  func demoCouchbaseLiteQueue() {
    let config = DatabaseConfiguration()
    config.directory = NSTemporaryDirectory()
    self.database = try! Database(name: UUID().uuidString, config: config)
    guard let database = self.database else {
      fatalError()
    }
    self.couchbaseLiteQueue = JobQueue(
      name: "CouchbaseLite Queue",
      schedulers: self.schedulers,
      storage: CouchbaseLiteStorage(database: database)
    )
    guard let queue = self.couchbaseLiteQueue else {
      return
    }
    self.demo(queue: queue)
  }

  func demo(queue: JobQueue) {
    self.queues[queue.name] = queue

    let id = ID(size: 10)

    queue.register(TestProcessor.self, concurrency: Int.random(in: 2...10))

    // Add 10 jobs
    let jobs = (0..<(Int.random(in: 0...25))).map { idx -> Job in
      let jobId = id.generate()
      return try! Job(
        TestProcessor.self,
        id: jobId,
        queueName: queue.name,
        payload: "Job #\(idx), ID: \(jobId)"
      )
    }
    SignalProducer(jobs)
      .flatMap(.merge) { queue.store($0) }
      .startWithCompleted {
        print("Finished storing jobs in queue: \(queue.name)")
        queue.resume().start()
      }
  }
}
