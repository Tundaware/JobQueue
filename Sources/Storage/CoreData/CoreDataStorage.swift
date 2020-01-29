///
///  Created by George Cox on 1/25/20.
///

import Foundation
import ReactiveSwift
import CoreData
#if SWIFT_PACKAGE
import JobQueueCore
#endif

@objc(JobCoreDataStorageEntity)
public class JobCoreDataStorageEntity: NSManagedObject {
  @NSManaged var id: JobID!
  @NSManaged var type: JobName!
  @NSManaged var queue: JobQueueName!
  @NSManaged var job: Data!

  func setJob(_ job: Job) throws {
    self.job = try JSONEncoder().encode(job)
    self.id = job.id
    self.queue = job.queueName
    self.type = job.type
  }
  func getJob() throws -> Job {
    try JSONDecoder().decode(Job.self, from: self.job)
  }
}

public class CoreDataStorage: JobStorage {
  private let logger: Logger
  private let createContext: () -> NSManagedObjectContext?
  private let rollback: (NSManagedObjectContext) -> Void
  private let commit: (NSManagedObjectContext) -> SignalProducer<Void, Error>

  public init(
    createContext: @escaping () -> NSManagedObjectContext,
    rollback: @escaping (NSManagedObjectContext) -> Void,
    commit: @escaping (NSManagedObjectContext) -> SignalProducer<Void, Error>,
    logger: Logger = ConsoleLogger()
  ) {
    self.createContext = createContext
    self.rollback = rollback
    self.commit = commit
    self.logger = logger
  }

  public func transaction<T>(
    queue: JobQueueProtocol,
    _ closure: @escaping (JobStorageTransaction) throws -> T
  ) -> SignalProducer<T, JobQueueError> {
    return SignalProducer { o, lt in
      guard let context = self.createContext() else {
        o.send(error: .storageNoDatabaseReference)
        return
      }
      let transaction = Transaction(
        queue: queue,
        context: context,
        logger: self.logger
      )
      do {
        let closureResult = try closure(transaction)
        self.commit(context).startWithResult { commitResult in
          switch commitResult {
          case .success:
            o.send(value: closureResult)
            o.sendCompleted()
          case .failure(let error):
            o.send(error: .unexpected(error))
          }
        }
      } catch {
        self.rollback(context)
        o.send(error: .from(error))
      }
    }
  }
}

extension CoreDataStorage {
  public enum Errors: Error {
    case noContext
  }
}

extension NSManagedObjectID {
  static func from(_ string: String, in context: NSManagedObjectContext) -> NSManagedObjectID? {
    guard let coordinator = context.persistentStoreCoordinator else {
      return nil
    }
    guard let url = URL(string: string) else {
      return nil
    }
    return coordinator.managedObjectID(forURIRepresentation: url)
  }
}
extension NSManagedObject {
  static func with(id: String, queue: JobQueueProtocol, in context: NSManagedObjectContext) -> Self? {
    guard let managedObjectID = NSManagedObjectID.from(id, in: context) else {
      return nil
    }
    return context.object(with: managedObjectID) as? Self
  }
}
