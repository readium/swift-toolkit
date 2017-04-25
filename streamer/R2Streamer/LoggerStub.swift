//
//  LoggerStub.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 3/8/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation

/// A Logger implementation of the Loggable protocol.
/// Used as default
public class LoggerStub: LoggerType {

    public init() {}

    /// Log `message` with a severity of `level`.
    public func log(level: SeverityLevel, message: String, _ path: String, _ function: String, _ className: String, _ line: Int) {
        let fileName = path.lastPathComponent
        let severity = LoggerStub.getSeverityString(for: level)

        print("🔸<\(severity)>[\(fileName)]: at \(function) \(line) : \(message)")
    }

    /// Print `value` with a severity of `level`.
    public func logValue(level: SeverityLevel, value: Any?, _ path: String, _ function: String, _ className: String, _ line: Int) {
        let fileName =  path.lastPathComponent
        // FIXME: This only works for objc types.
        let variableName = "" //NSPredicate(format: "%K == %@", #keyPath(value)), "test")
        let severity = LoggerStub.getSeverityString(for: level)

        print("🔸<\(severity)>[\(fileName)]: at \(function) \(line) : \(variableName) = \(value.debugDescription)")
    }

    /// Log `message` with a severity of `level`.
    static public func log(level: SeverityLevel, message: String, _ path: String, _ function: String, _ className: String, _ line: Int) {
        let fileName = path.lastPathComponent
        let severity = getSeverityString(for: level)

        print("🔸<\(severity)>[\(fileName)]: at \(function) \(line) : \(message)")
    }

    /// Print `value` with a severity of `level`.
    static public func logValue(level: SeverityLevel, value: Any?, _ path: String, _ function: String, _ className: String, _ line: Int) {
        let fileName =  path.lastPathComponent
        // FIXME: This only works for objc types.
        let variableName = "" //NSPredicate(format: "%K == %@", #keyPath(value)), "test")
        let severity = getSeverityString(for: level)

        print("🔸<\(severity)>[\(fileName)]: at \(function) (L.\(line) : \(variableName) = \(value.debugDescription)")
    }

    static private func getSeverityString(for level: SeverityLevel) -> String {
        switch level {
        case .verbose :
            return "verbose"
        case .debug :
            return "debug"
        case .info :
            return "info"
        case .warning :
            return "warning"
        case .error :
            return "error"
        }
    }
}
