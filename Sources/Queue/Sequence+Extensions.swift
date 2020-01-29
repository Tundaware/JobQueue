///
///  Created by George Cox on 1/22/20.
///

import Foundation
#if SWIFT_PACKAGE
import JobQueueCore
#endif

internal extension Sequence where Element == Job {
  var earliestDelayedJob: Element? {
    return self.delayedJobs
      .sorted { $0.delayedUntil! < $1.delayedUntil! }
      .first
  }

  var delayedJobs: [Job] {
    return self.filter { $0.status.isDelayed }
  }
}
