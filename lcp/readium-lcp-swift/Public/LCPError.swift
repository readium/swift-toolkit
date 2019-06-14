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
    // The operation can't be done right now because another License operation is running.
    case licenseIsBusy
    // An error occured while checking the integrity of the License, it can't be retrieved.
    case licenseIntegrity(Error)
    // The status of the License is not valid, it can't be used to decrypt the publication.
    case licenseStatus(StatusError)
    // Can't read or write the License Document from its container.
    case licenseContainer
    // The interaction is not available with this License.
    case licenseInteractionNotAvailable
    // This License's profile is not supported by liblcp.
    case licenseProfileNotSupported
    // Failed to renew the loan.
    case licenseRenew(RenewError)
    // Failed to return the loan.
    case licenseReturn(ReturnError)
    
    // Failed to retrieve the Certificate Revocation List.
    case crlFetching

    // Failed to parse information from the License or Status Documents.
    case parsing(ParsingError)
    // A network request failed with the given error.
    case network(Error?)
    // An unexpected LCP error occured. Please post an issue on r2-lcp-swift with the error message and how to reproduce it.
    case runtime(String)
    // An unknown low-level error was reported.
    case unknown(Error?)

}

extension LCPError: LocalizedError {
    
    public var errorDescription: String? {
        switch self {
        case .licenseIsBusy:
            return R2LCPLocalizedString("LCPError.licenseIsBusy")
        case .licenseIntegrity(let error):
            return error.localizedDescription
        case .licenseStatus(let error):
            return error.localizedDescription
        case .licenseContainer:
            return R2LCPLocalizedString("LCPError.licenseContainer")
        case .licenseInteractionNotAvailable:
            return R2LCPLocalizedString("LCPError.licenseInteractionNotAvailable")
        case .licenseProfileNotSupported:
            return R2LCPLocalizedString("LCPError.licenseProfileNotSupported")
        case .crlFetching:
            return R2LCPLocalizedString("LCPError.crlFetching")
        case .licenseRenew(let error):
            return error.localizedDescription
        case .licenseReturn(let error):
            return error.localizedDescription
        case .parsing(let error):
            return error.localizedDescription
        case .network(let error):
            return error?.localizedDescription ?? R2LCPLocalizedString("LCPError.network")
        case .runtime(let error):
            return error
        case .unknown(let error):
            return error?.localizedDescription
        }
    }
    
}


/// Errors while checking the status of the License, using the Status Document.
public enum StatusError: Error {
    // For the case (revoked, returned, cancelled, expired), app should notify the user and stop there. The message to the user must be clear about the status of the license: don't display "expired" if the status is "revoked". The date and time corresponding to the new status should be displayed (e.g. "The license expired on 01 January 2018").
    case cancelled(Date)
    case returned(Date)
    case expired(start: Date, end: Date)
    // If the license has been revoked, the user message should display the number of devices which registered to the server. This count can be calculated from the number of "register" events in the status document. If no event is logged in the status document, no such message should appear (certainly not "The license was registered by 0 devices").
    case revoked(Date, devicesCount: Int)
}

extension StatusError: LocalizedError {
    
    public var errorDescription: String? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        switch self {
        case .cancelled(let date):
            return R2LCPLocalizedString("StatusError.cancelled", dateFormatter.string(from: date))
            
        case .returned(let date):
            return R2LCPLocalizedString("StatusError.returned", dateFormatter.string(from: date))
            
        case .expired(start: let start, end: let end):
            if start > Date() {
                return R2LCPLocalizedString("StatusError.expired.start", dateFormatter.string(from: start))
            } else {
                return R2LCPLocalizedString("StatusError.expired.end", dateFormatter.string(from: end))
            }

        case .revoked(let date, let devicesCount):
            return R2LCPLocalizedString("StatusError.revoked", dateFormatter.string(from: date), devicesCount)
        }
    }
    
}


/// Errors while renewing a loan.
public enum RenewError: LocalizedError {
    // Your publication could not be renewed properly.
    case renewFailed
    // Incorrect renewal period, your publication could not be renewed.
    case invalidRenewalPeriod(maxRenewDate: Date?)
    // An unexpected error has occurred on the licensing server.
    case unexpectedServerError
    
    public var errorDescription: String? {
        switch self {
        case .renewFailed:
            return R2LCPLocalizedString("RenewError.renewFailed")
        case .invalidRenewalPeriod(maxRenewDate: _):
            return R2LCPLocalizedString("RenewError.invalidRenewalPeriod")
        case .unexpectedServerError:
            return R2LCPLocalizedString("RenewError.unexpectedServerError")
        }
    }
    
}


/// Errors while returning a loan.
public enum ReturnError: LocalizedError {
    // Your publication could not be returned properly.
    case returnFailed
    // Your publication has already been returned before or is expired.
    case alreadyReturnedOrExpired
    // An unexpected error has occurred on the licensing server.
    case unexpectedServerError
    
    public var errorDescription: String? {
        switch self {
        case .returnFailed:
            return R2LCPLocalizedString("ReturnError.returnFailed")
        case .alreadyReturnedOrExpired:
            return R2LCPLocalizedString("ReturnError.alreadyReturnedOrExpired")
        case .unexpectedServerError:
            return R2LCPLocalizedString("ReturnError.unexpectedServerError")
        }
    }
    
}


/// Errors while parsing the License or Status JSON Documents.
public enum ParsingError: Error {
    case malformedJSON
    case licenseDocument
    case statusDocument
    case link
    case encryption
    case signature
    case url(rel: String)
}

extension ParsingError: LocalizedError {
    
    public var errorDescription: String? {
        switch self {
        case .malformedJSON:
            return R2LCPLocalizedString("ParsingError.malformedJSON")
        case .licenseDocument:
            return R2LCPLocalizedString("ParsingError.licenseDocument")
        case .statusDocument:
            return R2LCPLocalizedString("ParsingError.statusDocument")
        case .link:
            return R2LCPLocalizedString("ParsingError.link")
        case .encryption:
            return R2LCPLocalizedString("ParsingError.encryption")
        case .signature:
            return R2LCPLocalizedString("ParsingError.signature")
        case .url(let rel):
            return R2LCPLocalizedString("ParsingError.url", rel)
        }
    }
    
}
