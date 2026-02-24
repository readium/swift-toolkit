//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// The different levels of log-severity available for logging.
public enum SeverityLevel: String, Sendable {
    case trace
    case debug
    case info
    case warning
    case error

    var name: String {
        rawValue
    }

    var symbol: String {
        switch self {
        case .trace:
            return "🐾"
        case .debug:
            return "🔎️"
        case .info:
            return "☝️"
        case .warning:
            return "⚠️"
        case .error:
            return "❌"
        }
    }

    var numericValue: Int {
        switch self {
        case .trace:
            return 1
        case .debug:
            return 2
        case .info:
            return 3
        case .warning:
            return 4
        case .error:
            return 5
        }
    }
}

/// Loggable protocol, to be implemented by a custom Logging class.
public protocol Loggable {}

/// Default implementation
public extension Loggable {
    func log(_ level: SeverityLevel, _ value: Any?, file: String = #file, line: Int = #line) {
        Logger.sharedInstance.log(value, at: level, file: file, line: line)
    }

    static func log(_ level: SeverityLevel, _ value: Any?, file: String = #file, line: Int = #line) {
        Logger.sharedInstance.log(value, at: level, file: file, line: line)
    }

    func logTrace(_ value: Any?, file: String = #file, line: Int = #line) {
        log(.trace, value, file: file, line: line)
    }

    static func logTrace(_ value: Any?, file: String = #file, line: Int = #line) {
        log(.trace, value, file: file, line: line)
    }

    func trace(_ message: String = "", function: String = #function, file: String = #file, line: Int = #line) {
        #if DEBUG
            log(.trace, "\(type(of: self))::\(function) \(message)", file: file, line: line)
        #endif
    }

    static func trace(_ message: String = "", function: String = #function, file: String = #file, line: Int = #line) {
        #if DEBUG
            log(.trace, "\(Self.self)::\(function) \(message)", file: file, line: line)
        #endif
    }

    func logDebug(_ value: Any?, file: String = #file, line: Int = #line) {
        log(.debug, value, file: file, line: line)
    }

    static func logDebug(_ value: Any?, file: String = #file, line: Int = #line) {
        log(.debug, value, file: file, line: line)
    }

    func logInfo(_ value: Any?, file: String = #file, line: Int = #line) {
        log(.info, value, file: file, line: line)
    }

    static func logInfo(_ value: Any?, file: String = #file, line: Int = #line) {
        log(.info, value, file: file, line: line)
    }

    func logWarning(_ value: Any?, file: String = #file, line: Int = #line) {
        log(.warning, value, file: file, line: line)
    }

    static func logWarning(_ value: Any?, file: String = #file, line: Int = #line) {
        log(.warning, value, file: file, line: line)
    }

    func logError(_ value: Any?, file: String = #file, line: Int = #line) {
        log(.error, value, file: file, line: line)
    }

    static func logError(_ value: Any?, file: String = #file, line: Int = #line) {
        log(.error, value, file: file, line: line)
    }

    @discardableResult func logAndRethrow<T>(_ block: () throws -> T) rethrows -> T {
        do {
            return try block()
        } catch {
            log(.error, error)
            throw error
        }
    }

    func warnIfMainThread(_ path: String = #file, _ function: String = #function, _ className: String = String(describing: Self.self), _ line: Int = #line) {
        if Self.isMainThread() {
            Logger.sharedInstance.log("\(className).\(function) should not be called from the main thread, as it might block the UI", at: .error, file: path, line: line)
        }
    }

    static func warnIfMainThread(_ path: String = #file, _ function: String = #function, _ className: String = String(describing: Self.self), _ line: Int = #line) {
        if isMainThread() {
            Logger.sharedInstance.log("\(className).\(function) should not be called from the main thread, as it might block the UI", at: .error, file: path, line: line)
        }
    }

    private static func isMainThread() -> Bool {
        #if DEBUG
            // Checks if we're not running from the unit tests.
            return NSClassFromString("XCTest") == nil && Thread.isMainThread
        #else
            return false
        #endif
    }
}
