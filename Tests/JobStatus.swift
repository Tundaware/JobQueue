///
///  Created by George Cox on 1/22/20.
///

import Foundation
import Nimble
import Quick
#if SWIFT_PACKAGE
import JobQueueCore
#endif

@testable import JobQueue

class JobStatusTests: QuickSpec {
  override func spec() {
    describe("when completed") {
      let date = Date(timeIntervalSince1970: 25)
      let status = JobStatus.completed(at: date)

      the("isCompleted property should be true") {
        expect(status.isComplete).to(beTrue())
      }
      the("isDelayed property should be false") {
        expect(status.isDelayed).to(beFalse())
      }
      the("isFailed property should be false") {
        expect(status.isFailed).to(beFalse())
      }
      the("completedAt date should be correct") {
        expect(status.completedAt).notTo(beNil())
        expect(status.completedAt!).to(equal(date))
      }
      the("failedAt date should be nil") {
        expect(status.failedAt).to(beNil())
      }
      the("failedAt message should be nil") {
        expect(status.failedMessage).to(beNil())
      }
      the("delayedUntil date should be nil") {
        expect(status.delayedUntil).to(beNil())
      }
    }

    describe("when delayed") {
      let date = Date(timeIntervalSince1970: 50)
      let status = JobStatus.delayed(until: date)

      the("isCompleted property should be false") {
        expect(status.isComplete).to(beFalse())
      }
      the("isDelayed property should be true") {
        expect(status.isDelayed).to(beTrue())
      }
      the("isFailed property should be false") {
        expect(status.isFailed).to(beFalse())
      }
      the("completedAt date should be nil") {
        expect(status.completedAt).to(beNil())
      }
      the("failedAt date should be nil") {
        expect(status.failedAt).to(beNil())
      }
      the("failedAt message should be nil") {
        expect(status.failedMessage).to(beNil())
      }
      the("delayedUntil date should be correct") {
        expect(status.delayedUntil).notTo(beNil())
        expect(status.delayedUntil!).to(equal(date))
      }
    }

    describe("when failed") {
      let date = Date(timeIntervalSince1970: 100)
      let message = "some error"
      let status = JobStatus.failed(at: date, message: message)

      the("isCompleted property should be false") {
        expect(status.isComplete).to(beFalse())
      }
      the("isDelayed property should be false") {
        expect(status.isDelayed).to(beFalse())
      }
      the("isFailed property should be true") {
        expect(status.isFailed).to(beTrue())
      }
      the("completedAt date should be nil") {
        expect(status.completedAt).to(beNil())
      }
      the("failedAt date should be correct") {
        expect(status.failedAt).notTo(beNil())
        expect(status.failedAt!).to(equal(date))
      }
      the("failedAt message should be correct") {
        expect(status.failedMessage).notTo(beNil())
        expect(status.failedMessage).to(equal(message))
      }
      the("delayedUntil date should be nil") {
        expect(status.delayedUntil).to(beNil())
      }
    }
  }
}
