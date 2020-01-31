///
///  Created by George Cox on 1/27/20.
///

import Foundation
import ReactiveSwift
import CoreData
#if SWIFT_PACKAGE
import JobQueueCore
#endif

extension CoreDataStorage {
  public class Transaction: JobStorageTransaction {
    private var queue: QueueIdentity?
    private let logger: Logger
    private let context: NSManagedObjectContext
    private typealias Entity = JobCoreDataStorageEntity

    internal let id = UUID().uuidString

    public init(
      queue: QueueIdentity? = nil,
      context: NSManagedObjectContext,
      logger: Logger
    ) {
      self.queue = queue
      self.context = context
      self.logger = logger
    }

    private func getEntities(queue: QueueIdentity?) -> Result<[Entity], JobQueueError> {
      guard let queue = (queue ?? self.queue) else {
        return .failure(.noQueueProvided)
      }
      let fetchRequest = Entity.fetchRequest()
      fetchRequest.predicate = NSPredicate(format: "queue == %@", queue.name)
      do {
        let rawResult = try context.fetch(fetchRequest)
        guard let result = rawResult as? [Entity] else {
          return .failure(.jobNotFound(queue.name, id))
        }
        return .success(result)
      } catch {
        return .failure(.unexpected(error))
      }
    }

    private func getEntity(_ id: Job.ID, queue: QueueIdentity?) -> Result<Entity, JobQueueError> {
      guard let queue = (queue ?? self.queue) else {
        return .failure(.noQueueProvided)
      }
      let fetchRequest = Entity.fetchRequest()
      fetchRequest.predicate = NSPredicate(format: "queue == %@ && id == %@", queue.name, id)
      do {
        guard let rawResult = try context.fetch(fetchRequest).first else {
          return .failure(.jobNotFound(queue.name, id))
        }
        guard let result = rawResult as? Entity else {
          return .failure(.jobNotFound(queue.name, id))
        }
        return .success(result)
      } catch {
        return .failure(.from(error))
      }
    }

    public func get(_ id: Job.ID, queue: QueueIdentity?) -> Result<Job, JobQueueError> {
      guard let queue = (queue ?? self.queue) else {
        return .failure(.noQueueProvided)
      }
      let entityResult = self.getEntity(id, queue: queue)
      switch entityResult {
      case .success(let entity):
        do {
          return .success(try entity.getJob())
        } catch {
          return .failure(.from(error))
        }
      case .failure(let error):
        return .failure(error)
      }
    }

    public func getAll(queue: QueueIdentity?) -> Result<[Job], JobQueueError> {
      guard let queue = (queue ?? self.queue) else {
        return .failure(.noQueueProvided)
      }
      let result = self.getEntities(queue: queue)
      switch result {
      case .success(let entities):
        do {
          return .success(try entities.map { try $0.getJob() })
        } catch {
          return .failure(.from(error))
        }
      case .failure(let error):
        return .failure(error)
      }
    }

    public func store(_ job: Job, queue: QueueIdentity?) -> Result<Job, JobQueueError> {
      guard let queue = (queue ?? self.queue) else {
        return .failure(.noQueueProvided)
      }
      let entityResult = self.getEntity(job.id, queue: queue)
      switch entityResult {
      case .success(let entity):
        // TODO: Guard for entity.Job.ID matching job.id
        // TODO: Guard for entity.jobQueueName matching queue.name
        do {
          try entity.setJob(job)
          return .success(job)
        } catch {
          return .failure(.from(error))
        }
      case .failure(let error):
        switch error {
        case .jobNotFound:
          let entity = Entity(context: self.context)
          do {
            try context.obtainPermanentIDs(for: [entity])
            try entity.setJob(job)
            return .success(job)
          } catch {
            return .failure(.from(error))
          }
        default:
          return .failure(error)
        }
      }
    }

    public func remove(_ id: Job.ID, queue: QueueIdentity?) -> Result<Job.ID, JobQueueError> {
      let result = self.getEntity(id, queue: queue)
      switch result {
      case .success(let entity):
        context.delete(entity)
        return .success(id)
      case .failure(let error):
        switch error {
        case .jobNotFound:
          return .success(id)
        default:
          return .failure(error)
        }
      }
    }

    public func remove(_ job: Job, queue: QueueIdentity?) -> Result<Job, JobQueueError> {
      let result = self.getEntity(job.id, queue: queue)
      switch result {
      case .success(let entity):
        context.delete(entity)
        return .success(job)
      case .failure(let error):
        switch error {
        case .jobNotFound:
          return .success(job)
        default:
          return .failure(error)
        }
      }
    }

    public func removeAll(queue: QueueIdentity?) -> Result<Void, JobQueueError> {
      let result = self.getEntities(queue: queue)
      switch result {
      case .success(let entities):
        entities.forEach { entity in
          context.delete(entity)
        }
        return .success(())
      case .failure(let error):
        return .failure(error)
      }
    }
  }
}
