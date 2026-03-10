//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumNavigator

/// Tracks object instances to detect memory leaks in UI tests.
@MainActor class MemoryTracker: ObservableObject {
    @Published var allDeallocated: Bool = true

    class Ref {
        private weak var object: AnyObject?

        var isDeallocated: Bool {
            object == nil
        }

        init(_ object: AnyObject) {
            self.object = object
        }
    }

    private var refs: [Ref] = []
    private var pollingTask: Task<Void, Never>?

    /// Records a weak reference to track.
    @discardableResult
    func track<T: AnyObject>(_ object: T) -> Ref {
        let ref = Ref(object)
        refs.append(ref)
        startPollingIfNeeded()
        return ref
    }

    private func startPollingIfNeeded() {
        guard pollingTask == nil else { return }

        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(seconds: 0.5)
                pollAllocations()
            }
        }
    }

    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func pollAllocations() {
        refs.removeAll { $0.isDeallocated }
        let deallocated = refs.isEmpty

        if allDeallocated != deallocated {
            allDeallocated = deallocated
        }

        // Stop polling when no objects are being tracked
        if refs.isEmpty {
            stopPolling()
        }
    }
}
