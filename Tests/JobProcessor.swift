///
///  Created by George Cox on 1/22/20.
///

import Foundation
#if SWIFT_PACKAGE
import JobQueue
import JobQueueCore
import JobQueueInMemoryStorage
#endif
import Nimble
import Quick
import ReactiveSwift

@testable import JobQueue

private class ForeverProcessor: Job.Processor<String> {
  override func process(job: Job, payload: String, queue: Queue) {}
}

class JobProcessorTests: QuickSpec {
  override func spec() {
    describe("changing status") {
      describe("verify change constraints") {
        var job: Job!
        var schedulers: Queue.Schedulers!
        var queue: Queue!
        var processor1: ForeverProcessor!
        var processor2: ForeverProcessor!
        var processor3: ForeverProcessor!
        var processor4: ForeverProcessor!
        var processor5: ForeverProcessor!

        beforeEach {
          job = try! Job(ForeverProcessor.self, id: "0", queueName: "test", payload: "test")
          schedulers = Queue.Schedulers()
          queue = Queue(
            name: "test",
            schedulers: schedulers,
            storage: InMemoryStorage(scheduler: schedulers.storage)
          )
          processor1 = ForeverProcessor()
          processor2 = ForeverProcessor()
          processor3 = ForeverProcessor()
          processor4 = ForeverProcessor()
          processor5 = ForeverProcessor()
        }
        it("should only allow changing status to `active` if current status is `new`") {
          waitUntil { done in
            let newToActive = { p in
              p.change(status: .active(job: job, queue: queue)).map { processor1.status.value }
            }(processor1)
            let newToCancelledToActive = { p in
              p.change(status: .cancelled(.queueSuspended))
                .then(p.change(status: .active(job: job, queue: queue)))
                .map { p.status.value }
            }(processor2)
            let newToActiveToCancelledToActive = { p in
              p.change(status: .active(job: job, queue: queue))
                .then(p.change(status: .cancelled(.queueSuspended)))
                .then(p.change(status: .active(job: job, queue: queue)))
                .map { p.status.value }
            }(processor3)
            let newToActiveToCompletedToActive = { p in
              p.change(status: .active(job: job, queue: queue))
                .then(p.change(status: .completed(at: Date())))
                .then(p.change(status: .active(job: job, queue: queue)))
                .map { p.status.value }
            }(processor4)
            let newToActiveToFailedToActive = { p in
              p.change(status: .active(job: job, queue: queue))
                .then(p.change(status: .failed(at: Date(), error: .abstractFunction("test"))))
                .then(p.change(status: .active(job: job, queue: queue)))
                .map { p.status.value }
            }(processor5)

            SignalProducer.combineLatest(
              newToActive,
              newToCancelledToActive,
              newToActiveToCancelledToActive,
              newToActiveToCompletedToActive,
              newToActiveToFailedToActive
            ).startWithResult { result in
              switch result {
              case .success(let results):
                expect(results.0).to(equal(.active(job: job, queue: queue)))
                expect(results.1).to(equal(.cancelled(.queueSuspended)))
                expect(results.2).to(equal(.cancelled(.queueSuspended)))
                expect(results.3).to(equal(.completed(at: Date())))
                expect(results.4).to(equal(.failed(at: Date(), error: .abstractFunction("test"))))
                done()
              case .failure(let error):
                fail(error.localizedDescription)
              }
            }
          }
        }
      }

      describe("cancelling") {
        context("when cancelled") {
          var processor: Processor1!

          beforeEach {
            processor = Processor1()
          }

          it("should send the cancel reason") {
            waitUntil { done in
              processor.status.producer.startWithValues { status in
                switch status {
                case .cancelled(let reason):
                  switch reason {
                  case .statusChangedToWaiting:
                    done()
                  default:
                    fail("Did not send the expected cancellation reason")
                  }
                default:
                  break
                }
              }
              processor.change(status: .cancelled(.statusChangedToWaiting)).start()
            }
          }
        }
      }

      describe("processing") {
        context("with an `AnyJobProcessor`") {
          context("a job whose payload doesn't match the processor's Payload type") {
            var queue: Queue!
            var schedulers: Queue.Schedulers!
            var storage: JobStorage!
            var processor: AnyJobProcessor!

            beforeEach {
              schedulers = Queue.Schedulers()
              storage = TestJobStorage(scheduler: schedulers.storage)

              queue = Queue(name: "test",
                               schedulers: schedulers,
                               storage: storage)
              processor = Processor2()
            }

            it("should send an error") {
              let job = try! Job(Processor1.self, id: "0", queueName: queue.name, payload: "test")
              processor.status.producer.startWithValues {
                switch $0 {
                case .completed: fail("should have failed")
                case .failed(_, let error):
                  expect({
                    switch error {
                    case .payloadDeserialization(let jobID, let queueName, _):
                      return jobID == "0" && queueName == queue.name
                    default: return false
                    }
                    }()).to(beTrue())
                default: break
                }
              }
              processor.change(status: .active(job: job, queue: queue))
                .start()
            }
          }
          context("that matches the processor's Payload type") {
            var queue: Queue!
            var schedulers: Queue.Schedulers!
            var storage: JobStorage!
            var processor: AnyJobProcessor!

            beforeEach {
              schedulers = Queue.Schedulers()
              storage = TestJobStorage(scheduler: schedulers.storage)

              queue = Queue(name: "test",
                               schedulers: schedulers,
                               storage: storage)
              processor = Job.Processor<String>()
              queue.register(Job.Processor<String>.self)
            }

            it("should send an error because the default job processor is abstract") {
              let job = try! Job(Processor1.self, id: "0", queueName: queue.name, payload: "test")
              processor.status.producer.startWithValues {
                switch $0 {
                case .completed:
                  fail("should have failed")
                case .failed(_, let error):
                  expect({
                    switch error {
                    case .abstractFunction: return true
                    default: return false
                    }
                  }()).to(beTrue())
                default: break
                }
              }
              processor.change(status: .active(job: job,
                                               queue: queue)).start()
            }
          }
        }

        context("a typed job") {
          var queue: Queue!
          var schedulers: Queue.Schedulers!
          var storage: JobStorage!
          var processor: AnyJobProcessor!

          beforeEach {
            schedulers = Queue.Schedulers()
            storage = TestJobStorage(scheduler: schedulers.storage)

            queue = Queue(name: "test",
                             schedulers: schedulers,
                             storage: storage)
            processor = Processor3()
          }

          it("should send an error because the default job processor is abstract") {
            let job = try! Job(Processor3.self, id: "0", queueName: queue.name, payload: "test")
            processor.status.producer.startWithValues {
              switch $0 {
              case .completed:
                fail("should have failed")
              case .failed(_, let error):
                expect({
                  switch error {
                  case .abstractFunction: return true
                  default: return false
                  }
                }()).to(beTrue())
              default: break
              }
            }
            processor.change(status: .active(job: job,
                                             queue: queue)).start()
          }
        }
      }
    }
  }
}
