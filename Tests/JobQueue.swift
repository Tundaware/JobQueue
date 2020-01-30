///
///  Created by George Cox on 1/22/20.
///

import Foundation
import Nimble
import Quick
import ReactiveSwift
#if SWIFT_PACKAGE
import JobQueueCore
#endif

@testable import JobQueue

private func randomString() -> String { UUID().uuidString }

class JobQueueTests: QuickSpec {
  override func spec() {
    var queue: JobQueue!
    var schedulers: JobQueueSchedulers!
    var storage: JobStorage!

    beforeEach {
      schedulers = JobQueueSchedulers()
      storage = TestJobStorage(scheduler: schedulers.storage)
      queue = JobQueue(name: randomString(),
                       schedulers: schedulers,
                       storage: storage,
                       delayStrategy: JobQueueDelayPollingStrategy(interval: 0.25))
    }
    describe("resuming") {
      it("should send true") {
        waitUntil { done in
          queue.resume().startWithResult { result in
            switch result {
            case .success(let isActive):
              expect(isActive).to(beTrue())
              done()
            case .failure(let error):
              fail("unexpected error: \(error)")
            }
          }
        }
      }
      it("should send a `resumed` event") {
        waitUntil { done in
          queue.events.producer.startWithValues { event in
            switch event {
            case .resumed:
              done()
            default:
              fail("should have resumed the queue")
            }
          }
          queue.resume().start()
        }
      }
      it("should set `isActive` to true") {
        waitUntil { done in
          queue.isActive.producer.skip(first: 1).startWithValues {
            expect($0).to(beTrue())
            done()
          }
          queue.resume().start()
        }
      }
    }
    describe("suspending") {
      it("should send false") {
        waitUntil { done in
          queue.resume()
            .then(queue.suspend())
            .startWithResult { result in
              switch result {
              case .success(let isActive):
                expect(isActive).to(beFalse())
                done()
              case .failure(let error):
                fail("unexpected error: \(error)")
              }
            }
        }
      }
      it("should send a `suspended` event") {
        waitUntil { done in
          queue.events.producer.skip(first: 1).startWithValues { event in
            switch event {
            case .suspended:
              done()
            default:
              fail("should have resumed the queue")
            }
          }
          queue.resume().then(queue.suspend()).start()
        }
      }
      it("should set `isActive` to false") {
        waitUntil { done in
          queue.isActive.producer.skip(first: 2).startWithValues {
            expect($0).to(beFalse())
            done()
          }
          queue.resume().then(queue.suspend()).start()
        }
      }
    }

    describe("storage interaction") {}

    describe("processing jobs") {
      describe("basic") {
        it("can process a job") {
          let job = try! Job(Processor1.self, id: "0", queueName: queue.name, payload: "test")
          queue.register(Processor1.self)
          var disposable: Disposable?
          waitUntil { done in
            disposable = queue.events.producer
              .startWithValues { event in
                switch event {
                case .finishedProcessing(let j):
                  expect(j.id).to(equal(job.id))
                  done()
                case .failedProcessing(_, let error):
                  fail("should not have failed, \(error)")
                  done()
                default:
                  break
                }
              }
            queue.store(job)
              .then(queue.resume())
              .start()
          }
          disposable?.dispose()
        }
        it("can process several jobs") {
          let jobs = (0..<25).reduce(into: [Job]()) { acc, idx in
            acc.append(try! Job(Processor1.self, id: "\(idx)", queueName: queue.name, payload: "test.\(idx)", order: Float(idx)))
          }
          queue.register(Processor1.self, concurrency: 50)
          var disposable: Disposable?
          waitUntil(timeout: 5) { done in
            let ids = Set(jobs.map { $0.id })
            var completed = Set<JobID>()

            disposable = queue.events.producer
              .startWithValues { event in
                switch event {
                case .finishedProcessing(let j):
                  completed.insert(j.id)
                  guard completed == ids else {
                    return
                  }
                  done()
                case .failedProcessing(_, let error):
                  fail("should not have failed, \(error)")
                  done()
                default:
                  break
                }
              }

            SignalProducer(jobs)
              .flatMap(.concat) { queue.store($0) }
              .then(queue.resume())
              .start()
          }

          disposable?.dispose()
        }
      }
      describe("delayed jobs") {
        it("should run the job after the delayed status' `until` date") {
          let date = Date(timeIntervalSinceNow: 2)
          let job = try! Job(Processor1.self,
            id: "delayed1",
            queueName: queue.name,
            payload: "delayed job",
            status: .delayed(until: date))

          queue.register(Processor1.self, concurrency: 50)
          var disposable: Disposable?

          waitUntil(timeout: 5) { done in
            disposable = queue.events.producer
              .startWithValues { event in
                switch event {
                case .beganProcessing:
                  guard Date() > date else {
                    fail("Began processing job prior to delay `until` date")
                    return
                  }
                case .finishedProcessing(let j):
                  guard Date() > date else {
                    fail("Processed job prior to delay `until` date")
                    return
                  }
                  expect(j.id).to(equal(job.id))
                  done()
                case .failedProcessing(_, let error):
                  fail("should not have failed, \(error)")
                default:
                  break
                }
              }
            queue.store(job)
              .then(queue.resume())
              .start()
          }
          disposable?.dispose()
        }
      }
    }
  }
}
