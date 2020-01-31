///
///  Created by George Cox on 1/27/20.
///

import Foundation
import ReactiveSwift
import CouchbaseLiteSwift

#if SWIFT_PACKAGE
import JobQueueCore
#endif

public class CouchbaseLiteStorage: JobStorage {
  let database: Database
  let logger: Logger

  public init(database: Database, logger: Logger = ConsoleLogger()) {
    self.database = database
    self.logger = logger
  }
  public func transaction<T>(
    queue: QueueIdentity,
    _ closure: @escaping (JobStorageTransaction) throws -> T
  ) -> SignalProducer<T, JobQueueError> {
    return SignalProducer { o, lt in
      do {
        var closureResult: T!
        try self.database.inBatch {
          let transaction = Transaction(
            queue: queue,
            database: self.database,
            logger: self.logger
          )
          closureResult = try closure(transaction)
        }
        o.send(value: closureResult)
        o.sendCompleted()
      } catch {
        o.send(error: .from(error))
      }
    }
  }
}
