//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Accumulates completion blocks.
/// This can be useful when an API is waiting for something before performing an action, and wants
/// to delay callers' completion blocks until ready.
///
/// ```
/// private let completions = CompletionList()
///
/// func performSomething(completion: (() -> Void)? = nil) {
///     let completion = completions.add(completion)
///     ...
/// }
/// ```
final class CompletionList {
    private var blocks: [() -> Void] = []

    /// Adds the given `completion` block the list.
    ///
    /// - Returns: A new block that will call all the registered completion blocks.
    @discardableResult
    func add(_ completion: (() -> Void)?) -> () -> Void {
        if let completion = completion {
            blocks.append(completion)
        }

        return {
            self.complete()
        }
    }

    /// Calls all the registered completion blocks.
    func complete() {
        DispatchQueue.main.async {
            for block in self.blocks {
                block()
            }
            self.blocks.removeAll()
        }
    }
}
