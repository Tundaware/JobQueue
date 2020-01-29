///
///  Created by George Cox on 1/27/20.
///

import CouchbaseLiteSwift
import Foundation
import ReactiveSwift

#if SWIFT_PACKAGE
import JobQueueCore
#endif

extension CouchbaseLiteStorage {
  public class Transaction: JobStorageTransaction {
    let queue: JobQueueProtocol?
    let database: Database
    let logger: Logger

    public init(queue: JobQueueProtocol? = nil, database: Database, logger: Logger) {
      self.queue = queue
      self.database = database
      self.logger = logger
    }

    private func key(from job: Job) -> String {
      return self.key(from: job.id, queueName: job.queueName)
    }

    private func key(from id: JobID, queueName: JobQueueName) -> String {
      return "\(queueName)/\(id)"
    }

    public func removeAll(queue: JobQueueProtocol?) -> Swift.Result<Void, JobQueueError> {
      guard let queue = (queue ?? self.queue) else {
        return .failure(.noQueueProvided)
      }

      let query = QueryBuilder
        .select(SelectResult.expression(Meta.id))
        .from(DataSource.database(self.database))
        .where(Expression.property("queue").equalTo(Expression.string(queue.name)))

      do {
        for result in try query.execute() {
          let id = result.string(forKey: "_id")!
          guard let document = database.document(withID: id) else {
            return .failure(.jobNotFound(id, queue.name))
          }
          try database.deleteDocument(document)
        }
        return .success(())
      } catch {
        return .failure(.unexpected(error))
      }
    }

    public func remove(_ job: Job, queue: JobQueueProtocol?) -> Swift.Result<Job, JobQueueError> {
      switch self.remove(job.id, queue: queue) {
      case .success:
        return .success(job)
      case .failure(let error):
        return .failure(error)
      }
    }

    public func remove(_ id: JobID, queue: JobQueueProtocol?) -> Swift.Result<JobID, JobQueueError> {
      guard let queue = (queue ?? self.queue) else {
        return .failure(.noQueueProvided)
      }

      do {
        guard let document = database.document(withID: self.key(from: id, queueName: queue.name)) else {
          return .failure(.jobNotFound(queue.name, id))
        }
        try database.deleteDocument(document)
        return .success(id)
      } catch {
        return .failure(.unexpected(error))
      }
    }

    public func store(_ job: Job, queue: JobQueueProtocol?) -> Swift.Result<Job, JobQueueError> {
      guard let queue = (queue ?? self.queue) else {
        return .failure(.noQueueProvided)
      }

      do {
        let _id = self.key(from: job)
        let document = database.document(withID: _id)?.toMutable() ?? MutableDocument(id: _id)
        document.setBlob(Blob(contentType: "application/json", data: try job.toData()), forKey: "details")
        document.setString(queue.name, forKey: "queue")
        try database.saveDocument(document)
        return .success(job)
      } catch {
        return .failure(.unexpected(error))
      }
    }

    public func getAll(queue: JobQueueProtocol?) -> Swift.Result<[Job], JobQueueError> {
      guard let queue = (queue ?? self.queue) else {
        return .failure(.noQueueProvided)
      }

      let query = QueryBuilder
        .select(SelectResult.expression(Meta.id),
                SelectResult.property("details"))
        .from(DataSource.database(self.database))
        .where(Expression.property("queue").equalTo(Expression.string(queue.name)))

      do {
        return .success(try query.execute().reduce(into: [Job]()) { acc, result in
          guard let blob = result.blob(forKey: "details") else {
            return
          }
          acc.append(try Job.from(blob: blob))
        })
      } catch {
        return .failure(.from(error))
      }
    }

    public func get(_ id: JobID, queue: JobQueueProtocol?) -> Swift.Result<Job, JobQueueError> {
      guard let queue = (queue ?? self.queue) else {
        return .failure(.noQueueProvided)
      }

      do {
        guard let document = database.document(withID: self.key(from: id, queueName: queue.name)) else {
          return .failure(.jobNotFound(queue.name, id))
        }
        guard let blob = document.blob(forKey: "details") else {
          return .failure(.jobNotFound(queue.name, id))
        }
        return .success(try .from(blob: blob))
      } catch {
        return .failure(.from(error))
      }
    }
  }
}

extension Job {
  func toData() throws -> Data {
    try JSONEncoder().encode(self)
  }

  static func from(blob: Blob) throws -> Self {
    guard let data = blob.content else {
      throw JobQueueError.jobDeserializationFailed
    }
    return try JSONDecoder().decode(Job.self, from: data)
  }
}
