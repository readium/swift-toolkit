//
//  Logger.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri on 3/8/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// Initialize the R2Logger.
/// Default logger is the `LoggerStub` class
///
/// - Parameter customLogger: The Logger that will be used for printing logs.
public func R2EnableLog(withMinimumSeverityLevel level: SeverityLevel, customLogger: LoggerType = LoggerStub()) -> () {
    Logger.sharedInstance.setupLogger(logger: customLogger)
    Logger.sharedInstance.setMinimumSeverityLevel(at: level)
    
    print("\(SeverityLevel.info.symbol) Readium 2 Log enabled with minimum severity level of [\(level)].")
}

/// The Logger protocol.
public protocol LoggerType {
    func log(level: SeverityLevel, value: Any?, file: String, line: Int)
}

/// Logger singleton.
public final class Logger {
    /// The active logger is responssible for displaying the log message
    /// throughout the framework. There is a default implementation `StubLogger`
    /// available. You can define your own implementation by applying the
    /// `Loggable` protocol to your xLogger class.
    internal var activeLogger: LoggerType?

    /// The minimum severity level for logs to be displayed.
    internal var minimumSeverityLevel: SeverityLevel?

    private(set) static var sharedInstance = Logger()

    // MARK: - Public methods.

    /// Setup the active logger, and optionally the minimumSeverityLevel.
    /// See `activeLogger` for more informations.
    ///
    /// - Parameters:
    ///   - logger: The logger to be used as the `activeLogger`.
    ///   - severityLevel: The minimum severity level of displayed logs.
    public func setupLogger(logger: LoggerType,
                            withMinimumSeverityLevel severityLevel: SeverityLevel? = .warning) {
        activeLogger = logger
        self.minimumSeverityLevel = severityLevel
    }

    /// Allow the framework user to set the minimum severity level for the logs
    /// being displayed.
    ///
    /// - Parameter severityLevel: The value from the `SeverityLevel` enum.
    public func setMinimumSeverityLevel(at severityLevel: SeverityLevel?) {
        guard let severityLevel = severityLevel else {
            return
        }
        self.minimumSeverityLevel = severityLevel
    }

    // MARK: - Internal methods.

    internal func log(_ value: Any?, at level: SeverityLevel, file: String, line: Int) {
        if let minimumSeverityLevel = minimumSeverityLevel {
            guard level.rawValue >= minimumSeverityLevel.rawValue else {
                return
            }
        }
        activeLogger?.log(level: level, value: value, file: file, line: line)
    }
}
