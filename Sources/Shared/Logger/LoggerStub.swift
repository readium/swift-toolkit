//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import os

/// A Logger implementation of the Loggable protocol.
/// Used as default
public struct LoggerStub: LoggerType {
    private let logger: os.Logger

    public init(subsystem: String = "org.readium.swift-toolkit", category: String = "Readium") {
        logger = os.Logger(subsystem: subsystem, category: category)
    }

    /// Log `message` with a severity of `level`.
    public func log(level: SeverityLevel, value: Any?, file: String, line: Int) {
        guard let value = value else {
            return
        }

        let fileName = (file as NSString).lastPathComponent
        let message = "\(level.symbol) \(fileName):\(line): \(String(describing: value))"

        switch level {
        case .trace, .debug:
            logger.debug("\(message, privacy: .public)")
        case .info:
            logger.info("\(message, privacy: .public)")
        case .warning:
            logger.warning("\(message, privacy: .public)")
        case .error:
            logger.error("\(message, privacy: .public)")
        }
    }
}
