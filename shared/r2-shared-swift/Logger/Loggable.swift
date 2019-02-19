//
//  Loggable.swift
//  r2-streamer-swift
//
//  Created by Alexandre Camilleri on 3/7/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// The different levels of log-severity available for logging.
public enum SeverityLevel: Int {
    case debug = 0
    case info
    case warning
    case error
    
    var name: String {
        switch self {
        case .debug:
            return "debug"
        case .info:
            return "info"
        case .warning:
            return "warning"
        case .error:
            return "error"
        }
    }
    
    var symbol: String {
        switch self {
        case .debug:
            return "⚪"
        case .info:
            return "⚫"
        case .warning:
            return "🔵"
        case .error:
            return "🔴"
        }
    }
}

/// Loggable protocol, to be implemented by a custom Logging class.
public protocol Loggable {

    /// Log `message` with a severity of `level`.
    func log(_ level: SeverityLevel, _ value: Any?, _ path: String, _ function: String, _ className: String, _ line: Int)

    // FIXME: code smell... But can't find a workaround for now...
    //       They used for logging in the initializer
    /// Log `message` with a severity of `level`.
    static func log(_ level: SeverityLevel, _ value: Any?, _ path: String, _ function: String, _ className: String, _ line: Int)
}

/// Default implementation
public extension Loggable {

    func log(_ level: SeverityLevel, _ value: Any?, _ path: String = #file, _ function: String = #function, _ className: String = String(describing: Self.self), _ line: Int = #line) {
        Logger.sharedInstance.log(value, at: level, path, function, className, line)
    }

    static func log(_ level: SeverityLevel, _ value: Any?, _ path: String = #file, _ function: String = #function, _ className: String = String(describing: Self.self), _ line: Int = #line) {
        Logger.sharedInstance.log(value, at: level, path, function, className, line)
    }

}
