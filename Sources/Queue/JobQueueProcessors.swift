///
///  Created by George Cox on 1/22/20.
///

import Foundation
#if SWIFT_PACKAGE
import JobQueueCore
#endif

struct JobProcessorConfiguration {
  let concurrency: Int
  let generate: () -> AnyJobProcessor

  init<T>(_ type: T.Type, concurrency: Int) where T: AnyJobProcessor {
    self.concurrency = concurrency
    self.generate = { T() }
  }
}

class JobQueueProcessors {
  var configurations = [JobName: JobProcessorConfiguration]()
  var active = [JobName: [JobID: AnyJobProcessor]]()

  /**
   Gets the active processors by filtering out processors for the provided list
   of `JobID`s.

   - Parameter excludedIDs: the job ids whose processors should be excluded from
   the result
   - Returns: a `[JobID: AnyJobProcessor]` that only includes active processors
   and excludes processors for any job whose id is in the `excludedIDs` list.
   */
  func activeProcessorsByID(excluding excludedIDs: [JobID]) -> [JobID: AnyJobProcessor] {
    return self.active.reduce(into: [JobID: AnyJobProcessor]()) { acc, kvp in
      kvp.value.filter {
        !excludedIDs.contains($0.key)
      }.forEach {
        acc[$0.key] = $0.value
      }
    }
  }

  /**
   Removes active processors

   - Parameter processorsToRemoveByJobID: the job IDs whose associated processors
   should be removed from the active processors collection.
   */
  func remove(processors processorsToRemoveByJobID: [JobID]) {
    self.active = self.active.reduce(into: [JobName: [JobID: AnyJobProcessor]]()) { acc, kvp in
      var nextProcessorsByJobID = kvp.value
      processorsToRemoveByJobID.forEach {
        nextProcessorsByJobID.removeValue(forKey: $0)
      }
      acc[kvp.key] = nextProcessorsByJobID
    }
  }

  /**
   Return true if the job already has an active processor

   - Parameter job: the job to check
   */
  func isProcessing(job: Job) -> Bool {
    return self.active[job.type]?[job.id] != nil
  }

  /**
   Gets or creates a processor for the provided job

   A new processor is created if a configuration exists for the job type, there
   is no processor for the job already, and the processor configuration's concurrency
   limit has not already been met.

   If a processor is created by this function, it is added to the `active` processors
   collection.

   - Parameter job: the job to provide a processor for
   */
  @discardableResult
  func activeProcessor(for job: Job) -> AnyJobProcessor? {
    var nextProcessors = self.active[job.type, default: [JobID: AnyJobProcessor]()]

    // If there's no configuration for this job type, return nil
    guard let configuration = self.configurations[job.type] else {
      return nil
    }

    // If there's already a processor for this job, return it
    if let processor = self.active[job.type]?[job.id] {
      return processor
    }

    // If the concurrency limit for this job type has been reached, return nil
    guard nextProcessors.count < configuration.concurrency else {
      return nil
    }

    // Generate a new processor and add it to the active processors collection
    let processor = configuration.generate()
    nextProcessors[job.id] = processor
    self.active[job.type] = nextProcessors
    return processor
  }
}
