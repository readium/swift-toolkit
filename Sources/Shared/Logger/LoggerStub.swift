//
//  LoggerStub.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri on 3/8/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// A Logger implementation of the Loggable protocol.
/// Used as default
public class LoggerStub: LoggerType {

    public init() {}

    /// Log `message` with a severity of `level`.
    public func log(level: SeverityLevel, value: Any?, file: String, line: Int) {
        guard let value = value else {
            return
        }
        let fileName =  URL(fileURLWithPath: file).lastPathComponent
        print("\(level.symbol) \(fileName):\(line):\t\(String(describing: value))")
    }

}
