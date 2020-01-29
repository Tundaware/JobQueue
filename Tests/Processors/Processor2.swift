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
class Processor2: DefaultJobProcessor<TestPayload1> {
  override func process(job: Job, payload: TestPayload1, queue: JobQueueProtocol, done: @escaping JobCompletion) {
    
  }
}
