[![SwiftPM compatible](https://img.shields.io/badge/SwiftPM-compatible-orange.svg)](#swift-package-manager) [![Cocoapods compatible](https://img.shields.io/cocoapods/v/JobQueue)](https://cocoapods.org/pods/JobQueue) [![GitHub release](https://img.shields.io/github/release/Tundaware/JobQueue.svg)](https://github.com/Tundaware/JobQueue/releases) ![Swift 5.1](https://img.shields.io/badge/Swift-5.1-orange.svg) ![platforms](https://img.shields.io/cocoapods/p/JobQueue)
[![Build Status](https://travis-ci.com/Tundaware/JobQueue.svg?token=68ifssJzBEm6iihApcf1&branch=master)](https://travis-ci.com/Tundaware/JobQueue)

# JobQueue

A persistent job queue with a simple API that does not depend on `Operation`/`OperationQueue`, is storage agnostic, supports for manual execution order, per job type concurrency limits, delayed jobs, and more.

## Features

- [x] No dependence on `Operation` or `OperationQueue`
- [x] Concurrency per job type
- [x] Manual processing order
- [x] Delayed jobs
- [x] Paused jobs
- [ ] Scheduled jobs
- [ ] Repeating jobs
- [ ] Rate limiting
- [x] Custom execution sorting
- [x] Storage agnostic
- [x] In memory storage implementation
- [ ] YapDatabase storage implementation
- [ ] Couchbase Lite storage implementation
- [ ] Core Data storage implementation
- [ ] Realm storage implementation

## Dependencies
### [ReactiveSwift](https://github.com/ReactiveCocoa/ReactiveSwift)
I didn't want to make a hard choice here, but I didn't have time to come up with a more 
flexible implementation. 
Ideally, I'd like to refactor it to have a core implementation that is
interacted with via an adapter that implements the asynchronous behavior so adapters 
could be written for GCD, RxSwift, ReactiveSwift, Combine, etc.

## Roadmap

This is alpha level code at this time. It needs more testing and profiling before being used in production.

Priorities are:
- [ ] Implementing `JobStorage` for `YapDatabase`, `Core Data`, `Realm`, and `Couchbase Lite`, in that order.
- [ ] Testing
- [ ] Profiling

## How to use

### Create a Job

```swift
struct SendAnEmail: Job {
  var id: JobID
  var rawPayload: [UInt8]
  var payload: Email
  var status: JobStatus
  var schedule: JobSchedule?
  var queuedAt: Date
  var order: Float?
  var progress: Float?
}

struct Email: Codable {
  var recipientAddress: String
  var senderAddress: String
  var subject: String
  var body: String
}
```

### Create a Processor

```swift
class SendEmailProcessor: DefaultJobProcessor<SendAnEmail> {
  override func process(job: SendAnEmail, queue: JobQueue, done: @escaping (Result<Void, Error>) -> Void) {
    doSomethingAsynchronous { error in
      if let error = error else {
        done(.failure(error))
      } else {
        done(.success(()))
      }
    }
  }
}
```

### Create a JobQueue instance

```swift
let schedulers = JobQueueSchedulers()
let storage = JobQueueInMemoryStorage()
let delayStrategy = JobQueueDelayPollingStrategy(interval: 0.25)

let queue = JobQueue(
  name: "email",
  schedulers: schedulers,
  storage: storage,
  delayStrategy: delayStrategy
)

// Register the processor and allow for processing up to 4 concurrent SendEmail jobs
queue.register(SendEmailProcessor.self, concurrency: 4)

// Resume the queue
queue.resume().startWithCompleted {
  print("Queue is running")
}
```

### Add a job

```swift
let email = Email(
  recipient: "a@b.com",
  sender: "c@d.com",
  subject: "Job Queue question",
  body: "Do you even use a job queue?"
)
let job = SendAnEmail(
  id: "email 1",
  rawPayload: try! SendAnEmail.serialize(email),
  payload: payload,
  status: status,
  queuedAt: queuedAt
)
queue.set(job).startWithCompleted {
  print("Stored a job")
}
```
