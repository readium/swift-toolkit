//
//  Loggable.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 3/7/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation

/// The different levels of log-severity available for logging.
public enum SeverityLevel: Int {
    case verbose = 0
    case debug
    case info
    case warning
    case error
}

/// Loggable protocol, to be implemented by a custom Logging class.
public protocol Loggable {

    /// Log `message` with a severity of `level`.
    func log(level: SeverityLevel, _ message: String, _ path: String,
             _ function: String, _ className: String, _ line: Int)

    /// Print `value` with a severity of `level`.
    func logValue(level: SeverityLevel, _ value: Any?, _ path: String,
                  _ function: String, _ className: String, _ line: Int)

    // FIXME: code smell... But can't find a workaround for now...
    //       They used for logging in the initializer
    /// Log `message` with a severity of `level`.
    static func log(level: SeverityLevel, _ message: String, _ path: String,
                    _ function: String, _ className: String, _ line: Int)

    /// Print `value` with a severity of `level`.
    static func logValue(level: SeverityLevel, _ value: Any?, _ path: String,
                         _ function: String, _ className: String, _ line: Int)
}

/// Default implementation
public extension Loggable {

    func log(level: SeverityLevel, _ message: String, _ path: String = #file,
             _ function: String = #function, _ className: String = String(describing: Self.self), _ line: Int = #line) {
        Logger.sharedInstance.log(message, at: level, path, function, className, line)
    }

    func logValue(level: SeverityLevel, _ value: Any?, _ path: String = #file,
                  _ function: String = #function, _ className: String = String(describing: Self.self), _ line: Int = #line) {
        Logger.sharedInstance.logValue(value, at: level, path, function, className, line)
    }

    static func log(level: SeverityLevel, _ message: String, _ path: String = #file,
             _ function: String = #function, _ className: String = String(describing: Self.self), _ line: Int = #line) {
        Logger.sharedInstance.log(message, at: level, path, function, className, line)
    }

    static func logValue(level: SeverityLevel, _ value: Any?, _ path: String = #file,
                  _ function: String = #function, _ className: String = String(describing: Self.self), _ line: Int = #line) {
        Logger.sharedInstance.logValue(value, at: level, path, function, className, line)
    }

}
