///
///  Created by George Cox on 1/22/20.
///

import Foundation
#if SWIFT_PACKAGE
import JobQueueCore
#endif
import JobQueue
import ReactiveSwift

class Processor1: DefaultJobProcessor<String> {
  let scheduler = QueueScheduler()

  var isProcessing: Bool = false

  override func process(job: Job, payload: String, queue: JobQueueProtocol, done: @escaping JobCompletion) {
    guard !isProcessing else {
      return
    }
    isProcessing = true
    scheduler.schedule(after: Date(timeIntervalSinceNow: Double.random(in: 0.1..<0.25))) {
      done(.success(()))
    }
  }
}