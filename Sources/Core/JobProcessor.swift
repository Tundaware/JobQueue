///
///  Created by George Cox on 1/22/20.
///

import Foundation
import ReactiveSwift

public protocol AnyJobProcessor {
  static var typeName: JobName { get }

  init()

  func cancel(reason: JobCancellationReason)
  func process(job: Job, queue: JobQueueProtocol, done: @escaping JobCompletion)
}
public protocol JobProcessor: AnyJobProcessor {
  associatedtype Payload: Codable

  func cancel(reason: JobCancellationReason)
  func process(job: Job, payload: Payload, queue: JobQueueProtocol, done: @escaping JobCompletion)
}

extension JobProcessor {
  /// Default implementation that uses the JSONEncoder
  ///
  /// - Parameter payload: the payload
  public static func serialize(_ payload: Payload) throws -> [UInt8] {
    return try .init(JSONEncoder().encode([payload]))
  }

  /// Default implementation that uses the JSONDecoder
  ///
  /// - Parameter rawPayload: the raw payload bytes
  public static func deserialize(_ rawPayload: [UInt8]) throws -> Payload {
    return try JSONDecoder().decode([Payload].self, from: .init(rawPayload)).first!
  }
}
