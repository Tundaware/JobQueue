///
///  Created by George Cox on 1/22/20.
///

import Foundation

extension Job {
  public enum Status: Equatable {
    case waiting
    case active
    case completed(at: Date)
    case delayed(until: Date)
    case failed(at: Date, message: String)
    case paused

    public var isActive: Bool {
      switch self {
      case .active:
        return true
      default:
        return false
      }
    }

    public var completedAt: Date? {
      switch self {
      case .completed(let date):
        return date
      default: return nil
      }
    }

    public var isComplete: Bool {
      switch self {
      case .completed:
        return true
      default:
        return false
      }
    }

    public var failedAt: Date? {
      switch self {
      case .failed(let date, _):
        return date
      default: return nil
      }
    }

    public var failedMessage: String? {
      switch self {
      case .failed(_, let message):
        return message
      default: return nil
      }
    }

    public var isFailed: Bool {
      switch self {
      case .failed:
        return true
      default:
        return false
      }
    }

    public var delayedUntil: Date? {
      switch self {
      case .delayed(let date):
        return date
      default: return nil
      }
    }

    public var isDelayed: Bool {
      switch self {
      case .delayed:
        return true
      default:
        return false
      }
    }
  }
}

extension Job.Status: Codable {
  enum CodingKeys: String, CodingKey {
    case simpleStatus
    case completedAt
    case delayedUntil
    case failedAt
    case failedMessage
  }

  enum SimpleStatus: String, Codable {
    case active
    case waiting
    case paused
    case failed
    case completed
    case delayed

    func toStatus(from values: KeyedDecodingContainer<Job.Status.CodingKeys>) throws -> Job.Status {
      switch self {
      case .active: return .active
      case .waiting: return .waiting
      case .paused: return .paused
      case .completed: return .completed(at: try values.decode(Date.self, forKey: .completedAt))
      case .failed: return .failed(at: try values.decode(Date.self, forKey: .failedAt),
                                   message: try values.decode(String.self, forKey: .failedMessage))
      case .delayed: return .delayed(until: try values.decode(Date.self, forKey: .delayedUntil))
      }
    }

    static func from(status: Job.Status) -> Self {
      switch status {
      case .active: return .active
      case .waiting: return .waiting
      case .paused: return .paused
      case .completed: return .completed
      case .failed: return .failed
      case .delayed: return .delayed
      }
    }
  }

  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    let simpleStatus = try values.decode(SimpleStatus.self, forKey: .simpleStatus)
    self = try simpleStatus.toStatus(from: values)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(SimpleStatus.from(status: self), forKey: .simpleStatus)
    switch self {
    case .completed(let date):
      try container.encode(date, forKey: .completedAt)
    case .failed(let date, let message):
      try container.encode(date, forKey: .failedAt)
      try container.encode(message, forKey: .failedMessage)
    case .delayed(let date):
      try container.encode(date, forKey: .delayedUntil)
    default: break
    }
  }
}
