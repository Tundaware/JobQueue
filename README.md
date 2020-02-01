[![SwiftPM compatible](https://img.shields.io/badge/SwiftPM-compatible-orange.svg)](#swift-package-manager) [![Cocoapods compatible](https://img.shields.io/cocoapods/v/JobQueue)](https://cocoapods.org/pods/JobQueue) [![GitHub release](https://img.shields.io/github/release/Tundaware/JobQueue.svg)](https://github.com/Tundaware/JobQueue/releases) ![Swift 5.1](https://img.shields.io/badge/Swift-5.1-orange.svg) ![platforms](https://img.shields.io/cocoapods/p/JobQueue)
[![Build](https://github.com/Tundaware/JobQueue/workflows/Build/badge.svg)](https://github.com/Tundaware/JobQueue/actions?query=workflow%3ABuild)
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
- [x] Couchbase Lite storage implementation
- [x] Core Data storage implementation
- [ ] Realm storage implementation

## Dependencies
### [ReactiveSwift](https://github.com/ReactiveCocoa/ReactiveSwift)
I didn't want to make a hard choice here, but I didn't have time to come up with a more
flexible implementation.
Ideally, I'd like to refactor it to have a core implementation that is
interacted with via an adapter that implements the asynchronous behavior so adapters
could be written for GCD, RxSwift, ReactiveSwift, Combine, etc.

## Install Notes
For CouchbaseLite storage support, you must use Cocoapods to install.

## Roadmap

This is alpha level code at this time. It needs more testing and profiling before being used in production.

Priorities are:
- [ ] Implement the remaining storage providers (YapDB & Realm)
- [ ] Testing
- [ ] Profiling

## How to use

### Create a Job

```swift
struct Email: Codable {
  var recipientAddress: String
  var senderAddress: String
  var subject: String
  var body: String
}

// If you inherit from the `DefaultJob<T>` class, all you need to do is override and implement the `process(?)` function
class SendAnEmail: DefaultJob<Email> {
  override func process(
    details: JobDetails,
    payload: Email,
    queue: JobQueueProtocol,
    done: @escaping JobCompletion
  ) {
    send(email: payload) { error in
      if let error = error {
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

let queue = JobQueue(
  name: "email",
  schedulers: schedulers,
  storage: storage
)

// Register the processor and allow for processing up to 4 concurrent SendEmail jobs
queue.register(SendAnEmail.self, concurrency: 4)

// Resume the queue
queue.resume().startWithCompleted {
  print("Resumed queue.")
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
let details = try! JobDetails(SendAnEmail.self, id: "email 1", queueName: queue.name, payload: email)
queue.store(details)
  .startWithCompleted {
    print("Stored a job")
  }
```
