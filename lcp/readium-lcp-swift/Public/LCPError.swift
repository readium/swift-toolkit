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
    case unknown(Error?)
    case network(Error?)
    case database(Error)
    case invalidLicense(Error?)
    case invalidPath
    case invalidLCPL
    case licenseNotFound
    case publicationLinkNotFound
    case hintLinkNotFound
    case statusLinkNotFound(String)
    case noStatusDocument
    case licenseDocumentData
    case publicationData
    case registrationFailure
    case returnFailure
    case alreadyReturned
    case alreadyExpired
    case renewFailure
    case renewPeriod
    case deviceId
    case unexpectedServerError
    case invalidHintData
    case container
    case licenseNotInContainer
    case invalidJSON
    case invalidContext
    case crlFetching
    case licenseFetching
    case missingLicenseStatus
    case profileNotSupported

    case invalidRights
    case invalidPassphrase
    case licenseAlreadyExist

/// For the case (revoked, returned, cancelled, expired), app should notify the user and stop there. The message to the user must be clear about the status of the license: don't display "expired" if the status is "revoked". The date and time corresponding to the new status should be displayed (e.g. "The license expired on 01 January 2018").
    case licenseStatusCancelled(Date?)
    case licenseStatusReturned(Date?)
    case licenseStatusExpired(Date?)
/// If the license has been revoked, the user message should display the number of devices which registered to the server. This count can be calculated from the number of "register" events in the status document. If no event is logged in the status document, no such message should appear (certainly not "The license was registered by 0 devices").
    case licenseStatusRevoked(Date?, devicesCount: Int)

    func localizedString(for date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM dd, yyyy HH:mm"
        
        dateFormatter.locale = Locale(identifier:"en")
        //.current // Change "en" to change the default locale if you want
        return dateFormatter.string(from: date)
    }
    
    func localizedSuffix(for date: Date?) -> String {
        if let theDate = date {
            return " on \(localizedString(for: theDate))"
        }
        return ""
    }
    
    internal static func wrap(_ error: Error) -> LCPError {
        if let lcpError = error as? LCPError {
            return lcpError
        }
            
        let nsError = error as NSError
        switch nsError.domain {
        case NSURLErrorDomain:
            return .network(nsError)
        default:
            return .unknown(error)
        }
    }
    
}

extension LCPError: LocalizedError {
    
    public var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Operation cancelled."
        case .unknown(let error):
            if let localizedError = error as? LocalizedError {
                return localizedError.errorDescription
            }
            return "Unknown error."
        case .invalidPath:
            return "The provided license file path is incorrect."
        case .invalidLCPL:
            return "The provided license isn't a correctly formatted LCPL file. "
        case .licenseNotFound:
            return "No license found in base for the given identifier."
        case .publicationLinkNotFound:
            return "The publication link is missing from the license document."
        case .hintLinkNotFound:
            return "The hint link is missing from the license document."
        case .statusLinkNotFound(let rel):
            return "The link \(rel) is missing from the Status Document."
        case .noStatusDocument:
            return "Updating the license failed, there is no status document."
        case .licenseDocumentData:
            return "Updating license failed, the fetche data is invalid."
        case .publicationData:
            return "The publication data is invalid."
        case .missingLicenseStatus:
            return "The license status couldn't be defined."
        case .licenseStatusReturned(let updatedDate):
            let suffix = self.localizedSuffix(for: updatedDate)
            return "This license has been returned\(suffix)."
        case .licenseStatusRevoked(let updatedDate, let devicesCount):
            let suffix = self.localizedSuffix(for: updatedDate)
            return "This license has been revoked by its provider" + suffix + ".\nThe license was registered by \(devicesCount) devices."
        case .licenseStatusCancelled(let updatedDate):
            let suffix = self.localizedSuffix(for: updatedDate)
            return "You have cancelled this license\(suffix)."
        case .licenseStatusExpired(let updatedDate):
            let suffix = self.localizedSuffix(for: updatedDate)
            return "The license status is expired\(suffix), if your provider allow it, you may be able to renew it."
        case .invalidRights:
            return "The rights of this license aren't valid."
        case .registrationFailure:
            return "The device could not be registered properly."
        case .returnFailure:
            return "Your publication could not be returned properly."
        case .alreadyReturned:
            return "Your publication has already been returned before."
        case .alreadyExpired:
            return "Your publication has already expired."
        case .renewFailure:
            return "Your publication could not be renewed properly."
        case .deviceId:
            return "Couldn't retrieve/generate a proper deviceId."
        case .unexpectedServerError:
            return "An unexpected error has occured."
        case .invalidHintData:
            return "The data returned by the server for the hint is not valid."
        case .container:
            return "Can't access the License Document container."
        case .licenseNotInContainer:
            return "The License Document can't be found in the container."
        case .invalidLicense(_):
            return "The License is not in a valid state."
        case .invalidJSON:
            return "The JSON license is not valid."
        case .invalidContext:
            return "The context provided is invalid."
        case .crlFetching:
            return "Error while fetching the certificate revocation list."
        case .licenseFetching:
            return "Error while fetching the License Document."
        case .invalidPassphrase:
            return "The passphrase entered is not valid."
        case .renewPeriod:
            return "Incorrect renewal period, your publication could not be renewed."
        case .licenseAlreadyExist:
            return "The LCP license already exist, this import is ignored"
        case .profileNotSupported:
            return "This Readium LCP license has a profile identifier that this app cannot handle, the publication cannot be processed"
        case .network(let error):
            // FIXME: use localized description
            return "Can't reach server: \(String(describing: error))"
        case .database(let error):
            return "Internal database error: \(error)"
        }
    }
}


