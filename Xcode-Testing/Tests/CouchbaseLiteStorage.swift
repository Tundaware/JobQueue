///
///  Created by George Cox on 1/28/20.
///

import Foundation
import Nimble
import Quick
import ReactiveSwift
import CouchbaseLiteSwift

@testable import JobQueue

class JobQueueCouchbaseLiteTests: QuickSpec {
  var database: Database!

  override func spec() {
    var storage: JobStorage!
    var queue: QueueIdentity!

    beforeEach {
      if self.database == nil {
        let config = DatabaseConfiguration()
        config.directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).absoluteString
        self.database = try! Database(name: "Testing", config: config)
      }
      guard let database = self.database else {
        fatalError()
      }

      queue = Queue()
      storage = CouchbaseLiteStorage(database: database)
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
              print("Failure fetching job: \(error)")
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
          }.on(failed: { error in
            fail(error.localizedDescription)
          }, value: { result in
            switch result {
            case .success(let job):
              expect(job.id).to(equal("1"))
              done()
            case .failure(let error):
              print("Failure fetching job: \(error)")
              fail(error.localizedDescription)
            }
          })
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
