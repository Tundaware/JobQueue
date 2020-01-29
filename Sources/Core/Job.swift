//
//  File.swift
//
//
//  Created by George Cox on 1/20/20.
//

import Foundation

public struct Job: Codable {
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

  public init<ProcessorType>(
    _ type: ProcessorType.Type,
    id: JobID,
    queueName: JobQueueName,
    payload: ProcessorType.Payload,
    queuedAt: Date = Date(),
    status: JobStatus = .waiting,
    schedule: JobSchedule? = nil,
    order: Float? = nil,
    progress: Float? = nil
  ) throws where ProcessorType: JobProcessor {
    self.type = ProcessorType.typeName
    self.id = id
    self.queueName = queueName
    self.payload = try ProcessorType.serialize(payload)
    self.queuedAt = queuedAt
    self.status = status
    self.schedule = schedule
    self.order = order
    self.progress = progress
  }
}
