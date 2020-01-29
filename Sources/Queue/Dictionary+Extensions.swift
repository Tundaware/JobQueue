///
///  Created by George Cox on 1/22/20.
///

import Foundation
#if SWIFT_PACKAGE
import JobQueueCore
#endif
internal extension Dictionary where Key == JobName, Value == [Job] {
  var jobIDs: [JobID] {
    return self.reduce(into: [JobID]()) { acc, kvp in
      acc.append(contentsOf: kvp.value.map { $0.id })
    }
  }
}
