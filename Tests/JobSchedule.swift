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

class JobScheduleTests: QuickSpec {
  override func spec() {
    describe("date interval") {
      describe("when using .timeInterval schedule") {
        let startDate = Date(timeIntervalSince1970: 25)
        let endDate = Date(timeIntervalSince1970: 250)
        let dateInterval = DateInterval(start: startDate, end: endDate)

        the("dateInterval property should match the provided dateInterval, if provided") {
          let schedule = JobSchedule.timeInterval(5, dateInterval)
          expect(schedule.dateInterval).to(equal(dateInterval))
        }
        
        the("dateInterval property should be correct when excluded") {
          let schedule = JobSchedule.timeInterval(5, nil)
          let expectation = DateInterval(start: Date.distantPast, end: Date.distantFuture)
          expect(schedule.dateInterval).to(equal(expectation))
        }
      }
    }
  }
}
