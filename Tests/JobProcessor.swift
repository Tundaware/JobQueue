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

class JobProcessorTests: QuickSpec {
  override func spec() {
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
          var queue: JobQueue!
          var schedulers: JobQueueSchedulers!
          var storage: JobStorage!
          var processor: AnyJobProcessor!

          beforeEach {
            schedulers = JobQueueSchedulers()
            storage = TestJobStorage(scheduler: schedulers.storage)

            queue = JobQueue(name: "test",
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
          var queue: JobQueue!
          var schedulers: JobQueueSchedulers!
          var storage: JobStorage!
          var processor: AnyJobProcessor!

          beforeEach {
            schedulers = JobQueueSchedulers()
            storage = TestJobStorage(scheduler: schedulers.storage)

            queue = JobQueue(name: "test",
                             schedulers: schedulers,
                             storage: storage)
            processor = JobProcessor<String>()
            queue.register(JobProcessor<String>.self)
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
        var queue: JobQueue!
        var schedulers: JobQueueSchedulers!
        var storage: JobStorage!
        var processor: AnyJobProcessor!

        beforeEach {
          schedulers = JobQueueSchedulers()
          storage = TestJobStorage(scheduler: schedulers.storage)

          queue = JobQueue(name: "test",
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
