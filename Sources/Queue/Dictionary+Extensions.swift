///
///  Created by George Cox on 1/22/20.
///

import Foundation
#if SWIFT_PACKAGE
import JobQueueCore
#endif
internal extension Dictionary where Key == Job.TypeName, Value == [Job] {
  var jobIDs: [Job.ID] {
    return self.reduce(into: [Job.ID]()) { acc, kvp in
      acc.append(contentsOf: kvp.value.map { $0.id })
    }
  }
}
