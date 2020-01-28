///
///  Created by George Cox on 1/22/20.
///

import Foundation
#if SWIFT_PACKAGE
import JobQueueCore
#endif
import JobQueue

struct TestPayload1: Codable, Equatable {
  var name: String
}
class TestJob2: DefaultJob<TestPayload1> {
  override func process(details: JobDetails, payload: TestPayload1, queue: JobQueueProtocol, done: @escaping JobCompletion) {
    
  }
}
