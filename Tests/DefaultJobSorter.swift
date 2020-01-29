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

class DefaultJobSorterTests: QuickSpec {
  override func spec() {
    describe("sort") {
      it("should sort by order, then queued at") {
        let jobs: [Job] = [
          try! Job(Processor1.self, id: "1", queueName: "", payload: "test", queuedAt: Date(timeIntervalSince1970: 200)),
          try! Job(Processor1.self, id: "0", queueName: "", payload: "test", queuedAt: Date(timeIntervalSince1970: 100)),
          try! Job(Processor1.self, id: "2", queueName: "", payload: "test", queuedAt: Date(timeIntervalSince1970: 75), order: 1.25),
          try! Job(Processor1.self, id: "4", queueName: "", payload: "test", queuedAt: Date(timeIntervalSince1970: 50), order: 1.25),
          try! Job(Processor1.self, id: "3", queueName: "", payload: "test", queuedAt: Date(timeIntervalSince1970: 25), order: 1.0)
        ]
        let sorted = DefaultJobSorter().sort(jobs: jobs)
        expect(sorted.map { $0.id }).to(equal(["3", "4", "2", "0", "1"]))
      }
    }
  }
}
