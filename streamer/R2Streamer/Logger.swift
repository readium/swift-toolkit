//
//  Logger.swift
//  r2-streamer-swift
//
//  Created by Alexandre Camilleri on 3/8/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared

@available(*, deprecated, message: "Use `R2Shared.R2EnableLog` instead")
public func R2StreamerEnableLog(withMinimumSeverityLevel level: SeverityLevel, customLogger: LoggerType = LoggerStub()) -> () {
    R2EnableLog(withMinimumSeverityLevel: level, customLogger: customLogger)
}
