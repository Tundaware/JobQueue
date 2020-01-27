//
//  File.swift
//
//
//  Created by George Cox on 1/20/20.
//

import Foundation

extension JobQueueName {
  static let unassignedJobQueueName = "UNASSIGNEDJOBQUEUENAME"
}

public struct JobDetails: Codable {
  public typealias EncodedPayload = [UInt8]

  /// Unique name that identifies the type
  public let type: JobName

  /// Unique identifier of the job
  public let id: JobID

  /// Queue name
  public let queueName: JobQueueName

  /// Raw payload bytes
  public let payload: EncodedPayload

  /// The date the job was added to the queue
  public let queuedAt: Date

  /// The job's status
  public var status: JobStatus

  /// The job's schedule, only for scheduled jobs
  public var schedule: JobSchedule?

  /// The specific order of the job in the queue. Sort order of jobs is by
  /// `order`, if not nil, then `queuedAt`
  public var order: Float?

  /// Optional progress of the job
  public var progress: Float?

  /// If a Job's `status` is delayed, it will have an associated date, which
  /// is returned by this property. The job won't be processed until after this
  /// date.
  public var delayedUntil: Date? { status.delayedUntil }

  /// The date the job completed successfully
  public var completedAt: Date? { status.completedAt }

  /// The date the job *last* failed
  public var failedAt: Date? { status.failedAt }

  /// The *last* error message for a failed job
  public var failedMessage: String? { status.failedMessage }

  internal init(
    type: JobName,
    id: JobID,
    queueName: JobQueueName,
    payload: EncodedPayload,
    queuedAt: Date = Date(),
    status: JobStatus = .waiting,
    schedule: JobSchedule? = nil,
    order: Float? = nil,
    progress: Float? = nil
  ) {
    self.type = type
    self.id = id
    self.queueName = queueName
    self.payload = payload
    self.queuedAt = queuedAt
    self.status = status
    self.schedule = schedule
    self.order = order
    self.progress = progress
  }

  public init<T>(
    _ type: T.Type,
    id: JobID,
    queueName: JobQueueName,
    payload: T.Payload,
    queuedAt: Date = Date(),
    status: JobStatus = .waiting,
    schedule: JobSchedule? = nil,
    order: Float? = nil,
    progress: Float? = nil
  ) throws where T: Job {
    self.type = T.typeName
    self.id = id
    self.queueName = queueName
    self.payload = try T.serialize(payload)
    self.queuedAt = queuedAt
    self.status = status
    self.schedule = schedule
    self.order = order
    self.progress = progress
  }
}

public protocol AnyJob {
  static var typeName: JobName { get }

  init()

  func cancel(reason: JobCancellationReason)
  func process(details: JobDetails, queue: JobQueueProtocol, done: @escaping JobCompletion)
}
public protocol Job: AnyJob {
  associatedtype Payload: Codable

  func cancel(reason: JobCancellationReason)
  func process(details: JobDetails, payload: Payload, queue: JobQueueProtocol, done: @escaping JobCompletion)
}

extension Job {
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
