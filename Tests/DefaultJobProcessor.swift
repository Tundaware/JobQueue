///
///  Created by George Cox on 1/22/20.
///

import Foundation
#if SWIFT_PACKAGE
import JobQueueCore
#endif
import Nimble
import Quick
import ReactiveSwift

@testable import JobQueue

class DefaultJobProcessorTests: QuickSpec {
  override func spec() {
    describe("cancelling") {
      context("when cancelled") {
        var processor: TestJob1!

        beforeEach {
          processor = TestJob1()
        }

        it("should send the cancel reason") {
          waitUntil { done in
            processor.cancelled.producer.startWithValues { reason in
              guard let reason = reason else {
                return
              }
              switch reason {
              case .statusChangedToWaiting:
                done()
              default:
                fail("Did not send the expected cancellation reason")
              }
            }
            processor.cancel(reason: .statusChangedToWaiting)
          }
        }
      }
    }

    describe("processing") {
      context("an `AnyJob`") {
        context("that doesn't match the processor's JobType") {
          var queue: JobQueue!
          var schedulers: JobQueueSchedulers!
          var storage: JobStorage!
          var processor: AnyJob!

          beforeEach {
            schedulers = JobQueueSchedulers()
            storage = TestJobStorage(scheduler: schedulers.storage)

            queue = JobQueue(name: "test",
                             schedulers: schedulers,
                             storage: storage)
            processor = TestJob2()
          }

          it("should send an error because the default job processor is abstract") {
            processor.process(details: try! JobDetails(TestJob1.self, id: "0", queueName: queue.name, payload: "test"),
                              queue: queue) { result in
              switch result {
              case .success:
                fail("should have failed")
              case .failure(let error):
                guard let e = error as? JobProcessorError else {
                  fail("unexpected error type: \(error)")
                  return
                }
                expect(e).to(equal(.invalidJobType))
              }
            }
          }
        }
        context("that matches the processor's JobType") {
          var queue: JobQueue!
          var schedulers: JobQueueSchedulers!
          var storage: JobStorage!
          var processor: AnyJob!

          beforeEach {
            schedulers = JobQueueSchedulers()
            storage = TestJobStorage(scheduler: schedulers.storage)

            queue = JobQueue(name: "test",
                             schedulers: schedulers,
                             storage: storage)
            processor = DefaultJob<String>()
            queue.register(DefaultJob<String>.self)
          }

          it("should send an error because the default job processor is abstract") {
            processor.process(details: try! JobDetails(TestJob1.self, id: "0", queueName: queue.name, payload: "test"),
                              queue: queue) { result in
              switch result {
              case .success:
                fail("should have failed")
              case .failure(let error):
                guard let e = error as? JobProcessorError else {
                  fail("unexpected error type: \(error)")
                  return
                }
                expect(e).to(equal(.abstractFunction))
              }
            }
          }
        }
      }

      context("a typed job") {
        var queue: JobQueue!
        var schedulers: JobQueueSchedulers!
        var storage: JobStorage!
        var processor: AnyJob!

        beforeEach {
          schedulers = JobQueueSchedulers()
          storage = TestJobStorage(scheduler: schedulers.storage)

          queue = JobQueue(name: "test",
                           schedulers: schedulers,
                           storage: storage)
          processor = TestJob3()
        }

        it("should send an error because the default job processor is abstract") {
          processor.process(details: try! JobDetails(TestJob3.self, id: "0", queueName: queue.name, payload: "test"),
                            queue: queue) { result in
            switch result {
            case .success:
              fail("should have failed")
            case .failure(let error):
              guard let e = error as? JobProcessorError else {
                fail("unexpected error type: \(error)")
                return
              }
              expect(e).to(equal(.abstractFunction))
            }
          }
        }
      }
    }
  }
}
