//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
import Testing

struct CancellableTasksTests {
    @Test func deinitCancelsInFlightTasks() async {
        let started = AsyncStream.makeStream(of: Void.self)
        let cancelled = AsyncStream.makeStream(of: Void.self)

        var sut: CancellableTasks? = CancellableTasks()
        sut!.add {
            started.continuation.yield(())
            while !Task.isCancelled {
                await Task.yield()
            }
            cancelled.continuation.yield(())
        }

        // Waits for the task to be running before releasing its owner.
        var startedIterator = started.stream.makeAsyncIterator()
        _ = await startedIterator.next()

        sut = nil

        // Hangs (and times out) if deallocating the owner did not cancel the
        // task.
        var cancelledIterator = cancelled.stream.makeAsyncIterator()
        _ = await cancelledIterator.next()
    }

    @Test func tasksRunToCompletionWhileOwnerIsAlive() async {
        let finished = AsyncStream.makeStream(of: Void.self)

        let sut = CancellableTasks()
        sut.add {
            finished.continuation.yield(())
        }

        var iterator = finished.stream.makeAsyncIterator()
        _ = await iterator.next()
    }
}
