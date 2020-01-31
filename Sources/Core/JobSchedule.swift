///
///  Created by George Cox on 1/22/20.
///

import Foundation

extension Job {
  public enum Schedule {
    // Process the job every n seconds. If a DateInterval is provided,
    // processing will only occur within that DateInterval.
    case timeInterval(TimeInterval, DateInterval?)

    public var dateInterval: DateInterval {
      switch self {
      case .timeInterval(_, let dateInterval):
        guard let dateInterval = dateInterval else {
          return DateInterval(start: Date.distantPast, end: Date.distantFuture)
        }
        return dateInterval
      }
    }
  }
}

extension Job.Schedule: Codable {
  enum CodingKeys: String, CodingKey {
    case simpleSchedule
    case timeInterval
    case dateInterval
  }
  enum SimpleSchedule: String, Codable {
    case timeInterval

    static func from(schedule: Job.Schedule) -> Self {
      switch schedule {
      case .timeInterval: return .timeInterval
      }
    }

    func toSchedule(from values: KeyedDecodingContainer<Job.Schedule.CodingKeys>) throws -> Job.Schedule {
      switch self {
      case .timeInterval:
        return .timeInterval(try values.decode(TimeInterval.self, forKey: .timeInterval),
                             try values.decode(DateInterval.self, forKey: .dateInterval))
      }
    }
  }

  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    let simpleSchedule = try values.decode(SimpleSchedule.self, forKey: .simpleSchedule)
    self = try simpleSchedule.toSchedule(from: values)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(SimpleSchedule.from(schedule: self), forKey: .simpleSchedule)
    switch self {
    case .timeInterval(let timeInterval, let dateInterval):
      try container.encode(timeInterval, forKey: .timeInterval)
      try container.encode(dateInterval, forKey: .dateInterval)
    }
  }
}
