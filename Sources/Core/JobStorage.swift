///
///  Created by George Cox on 1/22/20.
///

import Foundation
import ReactiveSwift

public protocol JobStorage {
  func transaction<T>(
    queue: JobQueueProtocol,
    _ closure: @escaping (JobStorageTransaction) throws -> T
  ) -> SignalProducer<T, JobQueueError>
}
