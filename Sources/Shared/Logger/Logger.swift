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
    Logger.sharedInstance.setupLogger(logger: customLogger, withMinimumSeverityLevel: level)

    print("\(SeverityLevel.info.symbol) Readium 2 Log enabled with minimum severity level of [\(level)].")
}

/// The Logger protocol.
public protocol LoggerType: Sendable {
    func log(level: SeverityLevel, value: Any?, file: String, line: Int)
}

/// Logger singleton.
public actor Logger {
    /// The active logger is responsible for displaying the log message
    /// throughout the framework.
    private var activeLogger: LoggerType?

    /// The minimum severity level for logs to be displayed.
    private var minimumSeverityLevel: SeverityLevel?

    /// Singleton instance.
    public static let sharedInstance = Logger()

    // MARK: - Public methods.

    /// Setup the active logger, and optionally the minimumSeverityLevel.
    /// See `activeLogger` for more informations.
    ///
    /// - Parameters:
    ///   - logger: The logger to be used as the `activeLogger`.
    ///   - severityLevel: The minimum severity level of displayed logs.
    public nonisolated func setupLogger(logger: LoggerType,
                                        withMinimumSeverityLevel severityLevel: SeverityLevel? = .warning)
    {
        Task {
            await updateState(logger: logger, level: severityLevel)
        }
    }

    /// Internal helper to update state within the actor's isolation.
    private func updateState(logger: LoggerType, level: SeverityLevel?) {
        activeLogger = logger
        minimumSeverityLevel = level
    }

    /// Allow the framework user to set the minimum severity level for the logs
    /// being displayed.
    ///
    /// - Parameter severityLevel: The value from the `SeverityLevel` enum.
    public nonisolated func setMinimumSeverityLevel(at severityLevel: SeverityLevel?) {
        guard let severityLevel = severityLevel else {
            return
        }

        Task {
            await updateLevel(severityLevel)
        }
    }

    private func updateLevel(_ level: SeverityLevel) {
        minimumSeverityLevel = level
    }

    // MARK: - Internal methods.

    /// Logs a value.
    nonisolated func log(_ value: Any?, at level: SeverityLevel, file: String, line: Int) {
        let safeValue = String(describing: value ?? "")

        Task {
            await performLog(safeValue, at: level, file: file, line: line)
        }
    }

    private func performLog(_ value: String, at level: SeverityLevel, file: String, line: Int) {
        if let minimumSeverityLevel = minimumSeverityLevel {
            guard level.numericValue >= minimumSeverityLevel.numericValue else {
                return
            }
        }

        activeLogger?.log(level: level, value: value, file: file, line: line)
    }
}
