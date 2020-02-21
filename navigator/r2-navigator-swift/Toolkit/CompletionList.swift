//
//  CompletionList.swift
//  r2-navigator-swift
//
//  Created by Mickaël Menu on 21/02/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
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
    func add(_ completion: (() -> Void)?) -> () -> Void {
        if let completion = completion {
            blocks.append(completion)
        }
        
        return {
            for block in self.blocks {
                block()
            }
            self.blocks.removeAll()
        }
    }
    
}
