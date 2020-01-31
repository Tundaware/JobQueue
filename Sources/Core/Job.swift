//
//  File.swift
//
//
//  Created by George Cox on 1/20/20.
//

import Foundation

public struct Job: Codable {
  public typealias EncodedPayload = [UInt8]
  public typealias ID = String
  public typealias TypeName = String

  /// Unique name that identifies the type
  public let type: TypeName

  /// Unique identifier of the job
  public let id: Job.ID

  /// Queue name
  public let queueName: QueueName

  /// Raw payload bytes
  public let payload: EncodedPayload

  /// The date the job was added to the queue
  public let queuedAt: Date

  /// The job's status
  public var status: Status

  /// The job's schedule, only for scheduled jobs
  public var schedule: Schedule?

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

  /// Initializes a job with an encoded payload
  ///
  /// - Parameters:
  ///   - type: The job's `JobType`
  ///   - id: The job's id
  ///   - queueName: The name of the queue
  ///   - payload: The encoded payload
  ///   - queuedAt: The queued at date
  ///   - status: The job's initial status
  ///   - schedule: The job's schedule (not supported yet)
  ///   - order: The job's manual execution order
  ///   - progress: The job's initial progress
  public init(
    type: TypeName,
    id: Job.ID,
    queueName: QueueName,
    payload: EncodedPayload,
    queuedAt: Date = Date(),
    status: Status = .waiting,
    schedule: Schedule? = nil,
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
}
