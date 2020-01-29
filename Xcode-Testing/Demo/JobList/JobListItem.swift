///
///  Created by George Cox on 1/29/20.
///

import JobQueue
import SwiftUI

extension JobStatus: CustomStringConvertible {
  public var description: String {
    switch self {
    case .active: return "active"
    case .waiting: return "waiting"
    case .paused: return "paused"
    case .completed: return "completed"
    case .delayed: return "delayed"
    case .failed: return "failed"
    }
  }
}

struct JobListAttribute: View {
  class ViewModel: ObservableObject {
    @Published var heading: String
    @Published var value: String

    init(heading: String, value: String) {
      self.heading = heading
      self.value = value
    }
  }

  @ObservedObject var viewModel: ViewModel

  var body: some View {
    HStack(alignment: .center) {
      Text(viewModel.heading)
      Text(viewModel.value).fontWeight(.medium)
    }
  }
}

struct JobListItem: View {
  @ObservedObject var state: JobViewModel

  var body: some View {
    VStack(alignment: .leading) {
      HStack {
        VStack(alignment: .leading) {
          JobListAttribute(viewModel: .init(heading: "id:", value: state.job.id))
          JobListAttribute(viewModel: .init(heading: "type:", value: state.job.type))
        }
        Spacer()
        JobListAttribute(viewModel: .init(heading: "status:", value: state.job.status.description))
      }
    }
  }
}

class JobViewModel: ObservableObject, Identifiable {
  @Published var job: Job
  var id: String { job.id }

  init(job: Job) {
    self.job = job
  }
}

#if DEBUG
struct ListItemView_Previews: PreviewProvider {
  static var previews: some View {
    JobListItem(state:
      JobViewModel(job: try! Job(TestProcessor.self, id: "1", queueName: "testqueue", payload: "Testing")))
  }
}
#endif
