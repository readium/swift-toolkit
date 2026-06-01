//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Initialize the Logger.
/// Default logger is the `LoggerStub` class
///
/// - Parameters:
///   - level: The minimum severity level for logs to be processed.
///   - customLogger: The Logger that will be used for printing logs.
///     Defaults to a `LoggerStub` which may perform no-op logging.
public func ReadiumEnableLog(withMinimumSeverityLevel level: SeverityLevel, customLogger: LoggerType = LoggerStub()) {
    Logger.sharedInstance.setupLogger(logger: customLogger, withMinimumSeverityLevel: level)

    print("\(SeverityLevel.info.symbol) Readium 2 Log enabled with minimum severity level of [\(level)].")
}

/// The Logger protocol.
public protocol LoggerType: Sendable {
    func log(level: SeverityLevel, value: String?, file: String, line: Int)
}

/// Logger singleton.
public final class Logger: Sendable {
    struct State {
        /// The active logger responsible for displaying the log messages
        /// throughout the framework. There is a default implementation `LoggerStub`
        /// available. You can define your own implementation by conforming your
        /// custom logger class to the `LoggerType` protocol.
        var activeLogger: LoggerType?

        /// The minimum severity level for logs to be displayed.
        var minimumSeverityLevel: SeverityLevel?
    }

    private let state = Mutex(State())

    static let sharedInstance = Logger()

    private init() {}

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
        state.withLock { currentState in
            currentState.activeLogger = logger
            currentState.minimumSeverityLevel = severityLevel
        }
    }

    /// Allow the framework user to set the minimum severity level for the logs
    /// being displayed.
    ///
    /// - Parameter severityLevel: The value from the `SeverityLevel` enum.
    public func setMinimumSeverityLevel(at severityLevel: SeverityLevel?) {
        guard let severityLevel else { return }
        state.withLock { currentState in
            currentState.minimumSeverityLevel = severityLevel
        }
    }

    // MARK: - Internal methods.

    func log(_ value: String?, at level: SeverityLevel, file: String, line: Int) {
        let logger: LoggerType? = state.withLock { currentState in
            if let minimumSeverityLevel = currentState.minimumSeverityLevel {
                guard level.numericValue >= minimumSeverityLevel.numericValue else { return nil }
            }
            return currentState.activeLogger
        }
        logger?.log(level: level, value: value, file: file, line: line)
    }
}
