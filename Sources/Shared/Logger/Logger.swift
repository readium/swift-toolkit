//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Initialize the Logger.
/// Default logger is the `LoggerStub` class
///
/// - Parameter customLogger: The Logger that will be used for printing logs.
public func ReadiumEnableLog(withMinimumSeverityLevel level: SeverityLevel, customLogger: LoggerType = LoggerStub()) {
    Logger.sharedInstance.setupLogger(logger: customLogger)
    Logger.sharedInstance.setMinimumSeverityLevel(at: level)

    print("\(SeverityLevel.info.symbol) Readium 2 Log enabled with minimum severity level of [\(level)].")
}

/// The Logger protocol.
public protocol LoggerType: Sendable {
    func log(level: SeverityLevel, value: Any?, file: String, line: Int)
}

/// Logger singleton.
public final class Logger: @unchecked Sendable {
    /// The active logger is responssible for displaying the log message
    /// throughout the framework. There is a default implementation `StubLogger`
    /// available. You can define your own implementation by applying the
    /// `Loggable` protocol to your xLogger class.
    private var _activeLogger: LoggerType?
    internal var activeLogger: LoggerType? {
        get { lock.withLock { _activeLogger } }
        set { lock.withLock { _activeLogger = newValue } }
    }

    /// The minimum severity level for logs to be displayed.
    private var _minimumSeverityLevel: SeverityLevel?
    internal var minimumSeverityLevel: SeverityLevel? {
        get { lock.withLock { _minimumSeverityLevel } }
        set { lock.withLock { _minimumSeverityLevel = newValue } }
    }

    private let lock = NSLock()

    public static let sharedInstance = Logger()

    // MARK: - Public methods.

    /// Setup the active logger, and optionally the minimumSeverityLevel.
    /// See `activeLogger` for more informations.
    ///
    /// - Parameters:
    ///   - logger: The logger to be used as the `activeLogger`.
    ///   - severityLevel: The minimum severity level of displayed logs.
    public func setupLogger(logger: LoggerType,
                            withMinimumSeverityLevel severityLevel: SeverityLevel? = .warning)
    {
        lock.withLock {
            _activeLogger = logger
            _minimumSeverityLevel = severityLevel
        }
    }

    /// Allow the framework user to set the minimum severity level for the logs
    /// being displayed.
    ///
    /// - Parameter severityLevel: The value from the `SeverityLevel` enum.
    public func setMinimumSeverityLevel(at severityLevel: SeverityLevel?) {
        guard let severityLevel = severityLevel else {
            return
        }
        minimumSeverityLevel = severityLevel
    }

    // MARK: - Internal methods.

    internal func log(_ value: Any?, at level: SeverityLevel, file: String, line: Int) {
        if let minimumSeverityLevel = minimumSeverityLevel {
            guard level.numericValue >= minimumSeverityLevel.numericValue else {
                return
            }
        }
        activeLogger?.log(level: level, value: value, file: file, line: line)
    }
}
