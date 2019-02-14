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
    case invalidLink(rel: String)
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
    case status(StatusError)
    case parsing(ParsingError)

    internal static func wrap(_ error: Error) -> LCPError {
        if let error = error as? LCPError {
            return error
        } else if let error = error as? StatusError {
            return .status(error)
        } else if let error = error as? ParsingError {
            return .parsing(error)
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
        case .invalidLink(rel: let rel):
            return "The link \(rel) is not valid."
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
        case .parsing(let error):
            return error.errorDescription ?? "Failed to parse the Document."
        }
    }
}
