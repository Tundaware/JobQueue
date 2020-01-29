///
///  Created by George Cox on 1/29/20.
///

import Foundation
import JobQueue

#if DEBUG
public let jobsPreviewData = [
  try! Job(TestProcessor.self, id: "1", queueName: "Memory", payload: "Testing", status: .completed(at: Date())),
  try! Job(TestProcessor.self, id: "2", queueName: "Memory", payload: "Testing", status: .active),
  try! Job(TestProcessor.self, id: "3", queueName: "Memory", payload: "Testing", status: .active),
  try! Job(TestProcessor.self, id: "4", queueName: "CoreData", payload: "Testing"),
  try! Job(TestProcessor.self, id: "5", queueName: "CoreData", payload: "Testing"),
  try! Job(TestProcessor.self, id: "6", queueName: "CouchbaseLite", payload: "Testing")
]
#endif
