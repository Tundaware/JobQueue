///
///  Created by George Cox on 1/29/20.
///

import JobQueue
import SwiftUI

extension Job: Identifiable {}
extension String: Identifiable {
  public var id: String { self }
}

class ListViewModel: ObservableObject {
  @Published var sections: [String]
  @Published var data: [String: [JobViewModel]]

  init(jobs: [Job]) {
    let data = Dictionary(grouping: jobs.map { JobViewModel(job: $0) }) { $0.job.queueName }
    self.data = data
    self.sections = data.keys.sorted()
  }
}

struct ListView: View {
  @ObservedObject var state: ListViewModel

  var body: some View {
    List {
      ForEach(self.state.sections) { section in
        Section(header: Text(section)) {
          ForEach(self.state.data[section]!) { job in
            JobListItem(state: job)
          }
        }
      }
    }
  }
}

#if DEBUG
struct ListView_Previews: PreviewProvider {
  static var previews: some View {
    let jobs = [
      try! Job(TestProcessor.self, id: "1", queueName: "Memory", payload: "Testing", status: .completed(at: Date())),
      try! Job(TestProcessor.self, id: "2", queueName: "Memory", payload: "Testing", status: .active),
      try! Job(TestProcessor.self, id: "3", queueName: "Memory", payload: "Testing", status: .active),
      try! Job(TestProcessor.self, id: "4", queueName: "CoreData", payload: "Testing"),
      try! Job(TestProcessor.self, id: "5", queueName: "CoreData", payload: "Testing"),
      try! Job(TestProcessor.self, id: "6", queueName: "CouchbaseLite", payload: "Testing")
    ]
    return ListView(state: ListViewModel(jobs: jobs))
  }
}
#endif
