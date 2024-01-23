//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

@available(*, unavailable, message: "Use `R2Shared.R2EnableLog` instead")
public func R2StreamerEnableLog(withMinimumSeverityLevel level: SeverityLevel, customLogger: LoggerType = LoggerStub()) {
    R2EnableLog(withMinimumSeverityLevel: level, customLogger: customLogger)
}
