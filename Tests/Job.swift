///
///  Created by George Cox on 1/22/20.
///

import Foundation
#if SWIFT_PACKAGE
import JobQueueCore
#endif
import Nimble
import Quick

@testable import JobQueue

private func randomString() -> String { UUID().uuidString }

class JobTests: QuickSpec {
  override func spec() {
    describe("status") {
      describe("when completed") {
        let date = Date(timeIntervalSince1970: 25)
        let status = JobStatus.completed(at: date)
        let job = try! Job(
          Processor1.self,
          id: randomString(),
          queueName: "",
          payload: "",
          status: status)

        the("status should be correct") {
          expect(job.status).to(equal(status))
        }
        the("completedAt property should match that of the status") {
          expect(job.status.completedAt == status.completedAt).to(beTrue())
        }
        the("failedAt property should match that of the status") {
          expect(job.failedAt == status.failedAt).to(beTrue())
        }
        the("failedMessage should match that of the status") {
          expect(job.failedMessage == status.failedMessage).to(beTrue())
        }
        the("delayedUntil should match that of the status") {
          expect(job.delayedUntil == status.delayedUntil).to(beTrue())
        }
      }
      describe("when delayed") {
        let date = Date(timeIntervalSince1970: 50)
        let status = JobStatus.delayed(until: date)
        let job = try! Job(
          Processor1.self,
          id: randomString(),
          queueName: "",
          payload: "",
          status: status)

        the("status should be correct") {
          expect(job.status).to(equal(status))
        }
        the("completedAt property should match that of the status") {
          expect(job.status.completedAt == status.completedAt).to(beTrue())
        }
        the("failedAt property should match that of the status") {
          expect(job.failedAt == status.failedAt).to(beTrue())
        }
        the("failedMessage should match that of the status") {
          expect(job.failedMessage == status.failedMessage).to(beTrue())
        }
        the("delayedUntil should match that of the status") {
          expect(job.delayedUntil == status.delayedUntil).to(beTrue())
        }
      }
      describe("when failed") {
        let date = Date(timeIntervalSince1970: 100)
        let message = "some failure"
        let status = JobStatus.failed(at: date, message: message)
        let job = try! Job(
          Processor1.self,
          id: randomString(),
          queueName: "",
          payload: "",
          status: status)

        the("status should be correct") {
          expect(job.status).to(equal(status))
        }
        the("completedAt property should match that of the status") {
          expect(job.status.completedAt == status.completedAt).to(beTrue())
        }
        the("failedAt property should match that of the status") {
          expect(job.failedAt == status.failedAt).to(beTrue())
        }
        the("failedMessage should match that of the status") {
          expect(job.failedMessage == status.failedMessage).to(beTrue())
        }
        the("delayedUntil should match that of the status") {
          expect(job.delayedUntil == status.delayedUntil).to(beTrue())
        }
      }
    }

    describe("serialization") {
      describe("JSON") {
        describe("simple payload") {
          describe("serialize") {
            it("should return the expected bytes") {
              let payload = "string"
              do {
                let bytes = try [UInt8](JSONEncoder().encode([payload]))
                let result = try Processor1.serialize(payload)
                expect(result.count).to(beGreaterThan(0))
                expect(result).to(equal(bytes))
              } catch {
                fail("Failed to serialize: \(error)")
              }
            }
          }
          describe("deserialize") {
            it("should return the expected payload") {
              let payload = "string"
              do {
                let serializeResult = try Processor1.serialize(payload)
                let deserializeResult = try Processor1.deserialize(serializeResult)
                expect(deserializeResult).to(equal(payload))
              } catch {
                fail("Failed to serialize: \(error)")
              }
            }
          }
        }

        describe("struct payload") {
          describe("serialize") {
            it("should return the expected bytes") {
              let payload = TestPayload1(name: "testing")
              do {
                let bytes = try [UInt8](JSONEncoder().encode([payload]))
                let result = try Processor2.serialize(payload)
                expect(result.count).to(beGreaterThan(0))
                expect(result).to(equal(bytes))
              } catch {
                fail("Failed to serialize: \(error)")
              }
            }
          }
          describe("deserialize") {
            it("should return the expected payload") {
              let payload = TestPayload1(name: "testing")
              do {
                let serializeResult = try Processor2.serialize(payload)
                let deserializeResult = try Processor2.deserialize(serializeResult)
                expect(deserializeResult).to(equal(payload))
              } catch {
                fail("Failed to serialize: \(error)")
              }
            }
          }
        }
      }
    }
  }
}
