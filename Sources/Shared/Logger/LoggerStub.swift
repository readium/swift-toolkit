//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A Logger implementation of the Loggable protocol.
/// Used as default
public class LoggerStub: LoggerType {
    public init() {}

    /// Log `message` with a severity of `level`.
    public func log(level: SeverityLevel, value: Any?, file: String, line: Int) {
        guard let value = value else {
            return
        }
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        print("\(level.symbol) \(fileName):\(line): \(String(describing: value))")
    }
}
