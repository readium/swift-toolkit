//
//  LCPError.swift
//  readium-lcp-swift
//
//  Created by Alexandre Camilleri on 9/6/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

public enum LCPError: Error {
    case cancelled
    case busyLicense
    case runtime(String)
    case unknown(Error?)
    case network(Error?)
    case invalidLCPL
    case linkNotFound(rel: String)
    case invalidURL(String)
    case noStatusDocument
    case deviceRegistration
    case returnFailure
    case alreadyReturned
    case renewFailure
    case renewPeriod
    case unexpectedServerError
    case container
    case licenseNotInContainer
    case invalidJSON
    case invalidContext
    case crlFetching
    case licenseFetching
    case profileNotSupported
    case invalidRights
    case status(LCPStatusError)
    
    internal static func wrap(_ error: Error) -> LCPError {
        if let lcpError = error as? LCPError {
            return lcpError
        } else if let statusError = error as? LCPStatusError {
            return .status(statusError)
        }
            
        let nsError = error as NSError
        switch nsError.domain {
        case NSURLErrorDomain:
            return .network(nsError)
        default:
            return .unknown(error)
        }
    }
    
    internal static func wrap<T>(_ completion: @escaping (T?, LCPError?) -> Void) -> (T?, Error?) -> Void {
        return { value, error in
            if let error = error {
                completion(value, LCPError.wrap(error))
            } else {
                completion(value, nil)
            }
        }
    }
    
}

extension LCPError: LocalizedError {
    
    public var errorDescription: String? {
        func localizedDescription(of error: Error?) -> String? {
            if let error = error as? LocalizedError {
                return error.errorDescription
            } else if let error = error as NSError? {
                return error.localizedDescription
            }
            return nil
        }
        
        switch self {
        case .cancelled:
            return "Operation cancelled."
        case .busyLicense:
            return "Can't perform the LCP operation at the moment, this license is busy."
        case .unknown(let error):
            if let message = localizedDescription(of: error) {
                return message
            }
            return "Unknown error."
        case .invalidLCPL:
            return "The provided license isn't a correctly formatted LCPL file. "
        case .linkNotFound(rel: let rel):
            return "The link \(rel) is missing from the Document."
        case .invalidURL(let url):
            return "The given URL is not valid: \(url)"
        case .noStatusDocument:
            return "Updating the license failed, there is no status document."
        case .invalidRights:
            return "The rights of this license aren't valid."
        case .deviceRegistration:
            return "The device could not be registered properly."
        case .returnFailure:
            return "Your publication could not be returned properly."
        case .alreadyReturned:
            return "Your publication has already been returned before."
        case .renewFailure:
            return "Your publication could not be renewed properly."
        case .unexpectedServerError:
            return "An unexpected error has occured."
        case .container:
            return "Can't access the License Document container."
        case .licenseNotInContainer:
            return "The License Document can't be found in the container."
        case .invalidJSON:
            return "The JSON license is not valid."
        case .invalidContext:
            return "The context provided is invalid."
        case .crlFetching:
            return "Error while fetching the certificate revocation list."
        case .licenseFetching:
            return "Error while fetching the License Document."
        case .renewPeriod:
            return "Incorrect renewal period, your publication could not be renewed."
        case .profileNotSupported:
            return "This Readium LCP license has a profile identifier that this app cannot handle, the publication cannot be processed"
        case .network(let error):
            if let message = localizedDescription(of: error) {
                return "Can't reach server: \(message)"
            } else {
                return "Network error."
            }
        case .runtime(let message):
            return "LCP internal error: \(message)"
        case .status(let error):
            return error.errorDescription ?? "This license's status is invalid."
        }
    }
}


public enum LCPStatusError: Error {
    // For the case (revoked, returned, cancelled, expired), app should notify the user and stop there. The message to the user must be clear about the status of the license: don't display "expired" if the status is "revoked". The date and time corresponding to the new status should be displayed (e.g. "The license expired on 01 January 2018").
    case cancelled(Date)
    case returned(Date)
    case expired(Date)
    // If the license has been revoked, the user message should display the number of devices which registered to the server. This count can be calculated from the number of "register" events in the status document. If no event is logged in the status document, no such message should appear (certainly not "The license was registered by 0 devices").
    case revoked(Date, devicesCount: Int)
    
}

extension LCPStatusError: LocalizedError {
    
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
