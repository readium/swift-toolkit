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
            return "Can't perform this operation at the moment."
        case .licenseIntegrity(let error):
            return error.localizedDescription
        case .licenseStatus(let error):
            return error.localizedDescription
        case .licenseContainer:
            return "Can't access the License Document."
        case .licenseInteractionNotAvailable:
            return "This interaction is not available."
        case .licenseProfileNotSupported:
            return "This License has a profile identifier that this app cannot handle, the publication cannot be processed."
        case .crlFetching:
            return "Can't retrieve the Certificate Revocation List."
        case .parsing(let error):
            return error.localizedDescription
        case .network(let error):
            return error?.localizedDescription ?? "Network error."
        case .runtime(let error):
            return error
        case .unknown(let error):
            return error?.localizedDescription
        }
    }
    
}
