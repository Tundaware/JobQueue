///
///  Created by George Cox on 1/24/20.
///

import JobQueue
import UIKit
import ReactiveSwift
import NanoID
import CouchbaseLiteSwift

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  let schedulers = JobQueueSchedulers()

  var inMemoryQueue: JobQueue?

  let coreDataStack = CoreDataStack()
  var coreDataQueue: JobQueue?

  var database: Database?
  var couchbaseLiteQueue: JobQueue?

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // Override point for customization after application launch.
    self.demoInMemoryQueue()
    self.demoCoreDataQueue()
    self.demoCouchbaseLiteQueue()
    return true
  }

  func demoInMemoryQueue() {
    self.inMemoryQueue = JobQueue(
      name: "InMemoryQueue",
      schedulers: schedulers,
      storage: InMemoryStorage(scheduler: schedulers.storage)
    )
    guard let queue = self.inMemoryQueue else {
      return
    }
    self.demo(queue: queue)
  }

  func demoCoreDataQueue() {
    self.coreDataQueue = JobQueue(
      name: "CoreDataQueue",
      schedulers: schedulers,
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
    self.database = try! Database(name: "Testing")
    guard let database = self.database else {
      fatalError()
    }
    self.couchbaseLiteQueue = JobQueue(
      name: "CouchbaseLite Queue",
      schedulers: schedulers,
      storage: CouchbaseLiteStorage(database: database)
    )
    guard let queue = self.couchbaseLiteQueue else {
      return
    }
    self.demo(queue: queue)
  }

  func demo(queue: JobQueue) {
    let id = ID(size: 10)

    queue.register(TestJob.self, concurrency: 3)

    // Add 10 jobs
    let jobs = (0..<10).map { idx -> JobDetails in
      let jobId = id.generate()
      return try! JobDetails(
        TestJob.self,
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

  // MARK: UISceneSession Lifecycle

  func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
  }

  func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
    // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
  }
}

class TestJob: DefaultJob<String> {
  override func process(details: JobDetails, payload: Payload, queue: JobQueueProtocol, done: @escaping JobCompletion) {
    QueueScheduler().schedule(after: Date().addingTimeInterval(5)) {
      done(.success(()))
    }
  }
}
