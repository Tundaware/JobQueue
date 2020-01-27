///
///  Created by George Cox on 1/25/20.
///

import Foundation
import JobQueueCore
import Nimble
import Quick
import ReactiveSwift

@testable import JobQueueInMemoryStorage

class JobQueueInMemoryStorageTests: QuickSpec {
  override func spec() {
    var storage: JobStorage!
    var queue: JobQueueProtocol!

    beforeEach {
      queue = Queue()
      storage = InMemoryStorage(scheduler: QueueScheduler())
    }

    describe("within transaction") {
      it("can store jobs") {
        waitUntil { done in
          storage.transaction(queue: queue) { tx in
            _ = tx.store(try! JobDetails(TestJob1.self, id: "1", queueName: "", payload: "test"))
            switch tx.get("1") {
            case .success(let job):
              expect(job.id).to(equal("1"))
              done()
            case .failure(let error):
              fail(error.localizedDescription)
            }
          }.startWithCompleted {}
        }
      }
      it("can remove jobs") {
        waitUntil { done in
          storage.transaction(queue: queue) { tx in
            _ = tx.store(try! JobDetails(TestJob1.self, id: "1", queueName: "", payload: "test"))
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
            _ = tx.store(try! JobDetails(TestJob1.self, id: "1", queueName: "", payload: "test"))
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
              fail(error.localizedDescription)
            }
          })
            .start()
        }
      }
      it("can remove jobs") {
        waitUntil { done in
          storage.transaction(queue: queue) { tx in
            _ = tx.store(try! JobDetails(TestJob1.self, id: "1", queueName: "", payload: "test"))
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

private class Queue: JobQueueProtocol {
  let name: String = "test queue"
}
