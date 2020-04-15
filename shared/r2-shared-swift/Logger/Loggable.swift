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
public enum SeverityLevel: String {
    case debug
    case info
    case warning
    case error
    
    var name: String {
        rawValue
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
    func log(_ level: SeverityLevel, _ value: Any?, file: String, line: Int)

    // FIXME: code smell... But can't find a workaround for now...
    //       They used for logging in the initializer
    /// Log `message` with a severity of `level`.
    static func log(_ level: SeverityLevel, _ value: Any?, file: String, line: Int)
}

/// Default implementation
public extension Loggable {
    
    func log(_ level: SeverityLevel, _ value: Any?, file: String, line: Int) {
        Logger.sharedInstance.log(value, at: level, file: file, line: line)
    }

    func log(_ level: SeverityLevel, _ value: Any?, defaultFile: String = #file, defaultLine: Int = #line) {
        Logger.sharedInstance.log(value, at: level, file: defaultFile, line: defaultLine)
    }

    static func log(_ level: SeverityLevel, _ value: Any?, file: String, line: Int) {
        Logger.sharedInstance.log(value, at: level, file: file, line: line)
    }

    static func log(_ level: SeverityLevel, _ value: Any?, defaultFile: String = #file, defaultLine: Int = #line) {
        Logger.sharedInstance.log(value, at: level, file: defaultFile, line: defaultLine)
    }

}
