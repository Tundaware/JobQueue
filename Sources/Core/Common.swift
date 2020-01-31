///
///  Created by George Cox on 1/22/20.
///

import Foundation

public typealias QueueName = String

public func notImplemented(_ message: @autoclosure () -> String = String(), file: StaticString = #file, line: UInt = #line) -> Never {
  let message = message()
  fatalError(message != String() ? message : "Not implemented", file: file, line: line)
}

public func abstract(_ message: @autoclosure () -> String = String(), file: StaticString = #file, line: UInt = #line) -> Never {
  let message = message()
  fatalError(message != String() ? message : "Function is abstract", file: file, line: line)
}

public typealias JobCompletion = (Result<Void, JobQueueError>) -> Void
public enum JobCancellationReason {
  case statusChangedToWaiting
  case statusChangedToDelayed
  case removed
  case statusChangedToPaused
  case queueSuspended
}

public enum JobQueueError: Error {
  case abstractFunction(String)
  case noQueueProvided
  case queueNotFound(QueueName)
  case jobNotFound(Job.ID, QueueName)
  case payloadDeserialization(Job.ID, QueueName, Error)
  case payloadSerialization(Job.ID, QueueName, Error)
  case jobDeserializationFailed
  case jobSerializationFailed
  case storageNoDatabaseReference
  case unexpected(Error)

  public static func from(_ error: Error) -> JobQueueError {
    guard let jobQueueError = error as? JobQueueError else {
      return .unexpected(error)
    }
    return jobQueueError
  }
}
