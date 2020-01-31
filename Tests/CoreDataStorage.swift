///
///  Created by George Cox on 1/27/20.
///

import CoreData
import Foundation
#if SWIFT_PACKAGE
import JobQueueCore
#endif
import Nimble
import Quick
import ReactiveSwift

#if SWIFT_PACKAGE
@testable import JobQueueCoreDataStorage
#else
@testable import JobQueue
#endif

class JobQueueCoreDataStorageTests: QuickSpec {
  private var stack: CoreDataStack!

  override func spec() {
    var storage: JobStorage!
    var queue: QueueIdentity!

    beforeEach {
      waitUntil { done in
        guard let _ = self.stack else {
          self.stack = CoreDataStack(done: {
            done()
          })
          return
        }
        done()
      }
      queue = Queue()
      storage = CoreDataStorage(
        createContext: self.stack.container.newBackgroundContext,
        rollback: self.stack.rollback,
        commit: self.stack.commit
      )
    }

    describe("within transaction") {
      it("can store jobs") {
        waitUntil { done in
          storage.transaction(queue: queue) { tx in
            _ = tx.store(try! Job(Processor1.self, id: "1", queueName: queue.name, payload: "test"))
            switch tx.get("1") {
            case .success(let job):
              expect(job.id).to(equal("1"))
              done()
            case .failure(let error):
              print("Can Store Jobs Error: \(error)")
              fail(error.localizedDescription)
            }
          }.startWithCompleted {}
        }
      }
      it("can remove jobs") {
        waitUntil { done in
          storage.transaction(queue: queue) { tx in
            _ = tx.store(try! Job(Processor1.self, id: "1", queueName: queue.name, payload: "test"))
          }.flatMap(.concat) {
            storage.transaction(queue: queue) { tx in
              _ = tx.remove("1")
              switch tx.get("1") {
              case .success:
                fail("Should have removed job")
              case .failure:
                done()
              }
            }
          }.start()
        }
      }
    }

    describe("after transaction") {
      it("can store jobs") {
        waitUntil { done in
          storage.transaction(queue: queue) { tx in
            _ = tx.store(try! Job(Processor1.self, id: "1", queueName: queue.name, payload: "test"))
          }.flatMap(.concat) {
            storage.transaction(queue: queue) { tx in
              tx.get("1")
            }
          }.on(
            failed: { error in
              print("Error storing jobs: \(error)")
              fail(error.localizedDescription)
            },
            value: { result in
              switch result {
              case .success(let job):
                expect(job.id).to(equal("1"))
                done()
              case .failure(let error):
                fail(error.localizedDescription)
              }
            }
          )
          .start()
        }
      }
      it("can remove jobs") {
        waitUntil { done in
          storage.transaction(queue: queue) { tx in
            _ = tx.store(try! Job(Processor1.self, id: "1", queueName: queue.name, payload: "test"))
          }.flatMap(.concat) {
            storage.transaction(queue: queue) { tx in
              _ = tx.remove("1")
            }
          }.flatMap(.concat) {
            storage.transaction(queue: queue) { tx in
              switch tx.get("1") {
              case .success:
                fail("Should have removed job")
              case .failure:
                done()
              }
            }
          }.start()
        }
      }
    }
  }
}

private class Queue: QueueIdentity {
  let name: String = "test queue"
}

private class CoreDataStack {
  let container: NSPersistentContainer
  let model = CoreDataStack.createModel()

  init(done: @escaping () -> Void) {
    self.container = NSPersistentContainer(name: "test", managedObjectModel: self.model)
    let desc = NSPersistentStoreDescription()
    desc.type = NSInMemoryStoreType
    self.container.persistentStoreDescriptions = [desc]
    self.container.loadPersistentStores { desc, error in
      guard let error = error else {
        done()
        return
      }
      print("Error loading persistent stores: \(error)")
      done()
    }
  }

  func rollback(_ ctx: NSManagedObjectContext) {
    ctx.reset()
  }

  func commit(_ ctx: NSManagedObjectContext) -> SignalProducer<Void, Error> {
    return SignalProducer { o, lt in
      typealias SaveFunction = (NSManagedObjectContext, Any) -> Void
      let save: SaveFunction = { ctx, _save in
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
      save(ctx, save)
    }
  }

  static func createModel() -> NSManagedObjectModel {
    let model = NSManagedObjectModel()

    let entity = NSEntityDescription()
    entity.name = "JobCoreDataStorageEntity"
    #if SWIFT_PACKAGE
    entity.managedObjectClassName = "JobCoreDataStorageEntity"
    #else
    entity.managedObjectClassName = "JobQueue.JobCoreDataStorageEntity"
    #endif
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
