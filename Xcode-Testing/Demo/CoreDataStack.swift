///
///  Created by George Cox on 1/27/20.
///

import CoreData
import Foundation
import JobQueue
import ReactiveSwift

class CoreDataStack {
  let container: NSPersistentContainer
  let model = CoreDataStack.createModel()

  init() {
    self.container = NSPersistentContainer(name: "test", managedObjectModel: self.model)
    let desc = NSPersistentStoreDescription()
    desc.type = NSSQLiteStoreType
    desc.url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(UUID().uuidString).db")
    self.container.persistentStoreDescriptions = [desc]
  }

  func load() -> SignalProducer<Void, Error> {
    return SignalProducer { o, lt in

      self.container.loadPersistentStores { desc, error in
        guard let error = error else {
          o.send(value: ())
          o.sendCompleted()
          return
        }
        print("Error loading persistent stores: \(error)")
        o.send(error: error)
      }
    }
  }

  func rollback(_ ctx: NSManagedObjectContext) {
    ctx.reset()
  }

  func commit(_ ctx: NSManagedObjectContext) -> SignalProducer<Void, Error> {
    return SignalProducer { o, lt in
      typealias SaveFunction = (NSManagedObjectContext, Any) -> Void
      let save: SaveFunction = { ctx, _save in
        ctx.perform {
          do {
            try ctx.save()
            guard let parent = ctx.parent else {
              o.send(value: ())
              o.sendCompleted()
              return
            }
            guard let saveParent = _save as? SaveFunction else {
              o.send(value: ())
              o.sendCompleted()
              return
            }
            saveParent(parent, _save)
          } catch {
            o.send(error: error)
          }
        }
      }
      save(ctx, save)
    }
  }

  static func createModel() -> NSManagedObjectModel {
    let model = NSManagedObjectModel()

    let entity = NSEntityDescription()
    entity.name = "JobCoreDataStorageEntity"
    entity.managedObjectClassName = "JobQueue.JobCoreDataStorageEntity"

    let jobID = NSAttributeDescription()
    jobID.attributeType = .stringAttributeType
    jobID.name = "id"
    jobID.isOptional = false

    let jobTypeName = NSAttributeDescription()
    jobTypeName.attributeType = .stringAttributeType
    jobTypeName.name = "type"
    jobTypeName.isOptional = false

    let jobQueueName = NSAttributeDescription()
    jobQueueName.attributeType = .stringAttributeType
    jobQueueName.name = "queue"
    jobQueueName.isOptional = false

    let job = NSAttributeDescription()
    job.attributeType = .binaryDataAttributeType
    job.name = "job"
    job.isOptional = false

    entity.properties = [jobID, jobTypeName, jobQueueName, job]
    model.entities = [entity]

    return model
  }
}
