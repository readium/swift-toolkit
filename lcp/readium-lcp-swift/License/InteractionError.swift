//
//  Created by Mickaël Menu on 14.02.19.
//  Copyright © 2019 Readium. All rights reserved.
//

import Foundation

// Errors occurring while performing an LSD interaction (eg. renew)
public enum InteractionError: Error {
    // This interaction is not available.
    case notAvailable
    // Your device could not be registered properly.
    case registerFailed
    // Your publication could not be returned properly.
    case returnFailed
    // Your publication has already been returned before or is expired.
    case alreadyReturnedOrExpired
    // Your publication could not be renewed properly.
    case renewFailed
    // Incorrect renewal period, your publication could not be renewed.
    case invalidRenewalPeriod
    // An unexpected error has occurred on the server.
    case unexpectedServerError
}

extension InteractionError: LocalizedError {
    
    public var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "This interaction is not available."
        case .registerFailed:
            return "Your device could not be registered properly."
        case .returnFailed:
            return "Your publication could not be returned properly."
        case .alreadyReturnedOrExpired:
            return "Your publication has already been returned before or is expired."
        case .renewFailed:
            return "Your publication could not be renewed properly."
        case .invalidRenewalPeriod:
            return "Incorrect renewal period, your publication could not be renewed."
        case .unexpectedServerError:
            return "An unexpected error has occurred on the server."
        }
    }
    
}
