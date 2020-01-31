///
///  Created by George Cox on 1/22/20.
///

import Foundation
#if SWIFT_PACKAGE
import JobQueueCore
#endif
import JobQueue
import ReactiveSwift

class Processor1: Job.Processor<String> {
  let scheduler = QueueScheduler()

  var isProcessing: Bool = false

  override func process(job: Job, payload: String, queue: Queue) {
    guard !isProcessing else {
      return
    }
    isProcessing = true
    scheduler.schedule(after: Date(timeIntervalSinceNow: Double.random(in: 0.1..<0.25))) {
      self.change(status: .completed(at: Date())).start()
    }
  }
}
