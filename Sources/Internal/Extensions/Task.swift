//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public final class CancellableTasks {
    fileprivate var tasks: Set<Task<Void, Never>> = []

    public init() {}
    
    deinit {
        for task in tasks {
            task.cancel()
        }
    }
}

public extension Task where Success == Void, Failure == Never {
    func store(in set: CancellableTasks) {
        set.tasks.insert(self)
    }
}

public extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
