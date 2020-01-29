///
///  Created by George Cox on 1/29/20.
///

import Combine
import JobQueue
import ReactiveSwift
import SwiftUI

class Jobs: ObservableObject {
  @Published var jobs: [Job] = [Job]()

  init(jobs: [Job]) {
    self.jobs = jobs

    SignalProducer.combineLatest(Queues.shared.queues.values.map { $0.events.producer })
      .flatMap(.latest) { _ in
        SignalProducer.combineLatest(Queues.shared.queues.values.map { $0.getAll() })
      }
      .map {
        $0.reduce(into: [Job]()) { acc, jobs in
          acc.append(contentsOf: jobs.filter { !$0.status.isComplete })
        }
      }
      .observe(on: QueueScheduler.main)
      .startWithResult { result in
        switch result {
        case .success(let jobs):
          self.jobs = jobs
        case .failure(let error):
          print("Error observing queues: \(error)")
        }
      }
  }
}

struct ContentView: View {
  @ObservedObject var state: Jobs

  var body: some View {
    ListView(state: ListViewModel(jobs: state.jobs))
  }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView(state: Jobs(jobs: jobsPreviewData))
  }
}
#endif
