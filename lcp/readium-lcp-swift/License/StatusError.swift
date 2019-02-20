//
//  StatusError.swift
//  r2-lcp-swift
//
//  Created by Mickaël Menu on 14.02.19.
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

public enum StatusError: Error {
    // For the case (revoked, returned, cancelled, expired), app should notify the user and stop there. The message to the user must be clear about the status of the license: don't display "expired" if the status is "revoked". The date and time corresponding to the new status should be displayed (e.g. "The license expired on 01 January 2018").
    case cancelled(Date)
    case returned(Date)
    case expired(Date)
    // If the license has been revoked, the user message should display the number of devices which registered to the server. This count can be calculated from the number of "register" events in the status document. If no event is logged in the status document, no such message should appear (certainly not "The license was registered by 0 devices").
    case revoked(Date, devicesCount: Int)
}

extension StatusError: LocalizedError {
    
    public var errorDescription: String? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM dd, yyyy HH:mm"
        dateFormatter.locale = Locale(identifier:"en")
        
        switch self {
        case .cancelled(let date):
            return "You have cancelled this license on \(dateFormatter.string(from: date))."
            
        case .returned(let date):
            return "This license has been returned on \(dateFormatter.string(from: date))."
            
        case .expired(let date):
            return "This license expired on \(dateFormatter.string(from: date)).\nIf your provider allows it, you may be able to renew it."
            
        case .revoked(let date, let devicesCount):
            return "This license has been revoked by its provider on \(dateFormatter.string(from: date)).\nThe license was registered by \(devicesCount) device\(devicesCount > 1 ? "s" : "")."
        }
    }
    
}
