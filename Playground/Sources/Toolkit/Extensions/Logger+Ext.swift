//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import OSLog

extension Logger {
    /// Initialize a logger with the category set to the `type` name.
    init<T>(for type: T.Type) {
        self.init(subsystem: Bundle.main.bundleIdentifier!, category: String(describing: type))
    }

    func error(_ error: Error) {
        self.error("\(error.localizedDescription)")
    }
}
