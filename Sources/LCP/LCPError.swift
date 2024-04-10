//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public enum LCPError: LocalizedError {
    // The operation can't be done right now because another License operation is running.
    case licenseIsBusy
    // An error occured while checking the integrity of the License, it can't be retrieved.
    case licenseIntegrity(LCPClientError)
    // The status of the License is not valid, it can't be used to decrypt the publication.
    case licenseStatus(StatusError)
    // Can't read or write the License Document from its container.
    case licenseContainer(ContainerError)
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

    public var errorDescription: String? {
        switch self {
        case .licenseIsBusy:
            return ReadiumLCPLocalizedString("LCPError.licenseIsBusy")
        case let .licenseIntegrity(error):
            let description: String = {
                switch error {
                case .licenseOutOfDate:
                    return ReadiumLCPLocalizedString("LCPClientError.licenseOutOfDate")
                case .certificateRevoked:
                    return ReadiumLCPLocalizedString("LCPClientError.certificateRevoked")
                case .certificateSignatureInvalid:
                    return ReadiumLCPLocalizedString("LCPClientError.certificateSignatureInvalid")
                case .licenseSignatureDateInvalid:
                    return ReadiumLCPLocalizedString("LCPClientError.licenseSignatureDateInvalid")
                case .licenseSignatureInvalid:
                    return ReadiumLCPLocalizedString("LCPClientError.licenseSignatureInvalid")
                case .contextInvalid:
                    return ReadiumLCPLocalizedString("LCPClientError.contextInvalid")
                case .contentKeyDecryptError:
                    return ReadiumLCPLocalizedString("LCPClientError.contentKeyDecryptError")
                case .userKeyCheckInvalid:
                    return ReadiumLCPLocalizedString("LCPClientError.userKeyCheckInvalid")
                case .contentDecryptError:
                    return ReadiumLCPLocalizedString("LCPClientError.contentDecryptError")
                case .unknown:
                    return ReadiumLCPLocalizedString("LCPClientError.unknown")
                }
            }()
            return ReadiumLCPLocalizedString("LCPError.licenseIntegrity", description)
        case let .licenseStatus(error):
            return error.localizedDescription
        case .licenseContainer:
            return ReadiumLCPLocalizedString("LCPError.licenseContainer")
        case .licenseInteractionNotAvailable:
            return ReadiumLCPLocalizedString("LCPError.licenseInteractionNotAvailable")
        case .licenseProfileNotSupported:
            return ReadiumLCPLocalizedString("LCPError.licenseProfileNotSupported")
        case .crlFetching:
            return ReadiumLCPLocalizedString("LCPError.crlFetching")
        case let .licenseRenew(error):
            return error.localizedDescription
        case let .licenseReturn(error):
            return error.localizedDescription
        case .parsing:
            return ReadiumLCPLocalizedString("LCPError.parsing")
        case let .network(error):
            return error?.localizedDescription ?? ReadiumLCPLocalizedString("LCPError.network")
        case let .runtime(error):
            return error
        case let .unknown(error):
            return error?.localizedDescription
        }
    }
}

/// Errors while checking the status of the License, using the Status Document.
public enum StatusError: LocalizedError {
    // For the case (revoked, returned, cancelled, expired), app should notify the user and stop there. The message to the user must be clear about the status of the license: don't display "expired" if the status is "revoked". The date and time corresponding to the new status should be displayed (e.g. "The license expired on 01 January 2018").
    case cancelled(Date)
    case returned(Date)
    case expired(start: Date, end: Date)
    // If the license has been revoked, the user message should display the number of devices which registered to the server. This count can be calculated from the number of "register" events in the status document. If no event is logged in the status document, no such message should appear (certainly not "The license was registered by 0 devices").
    case revoked(Date, devicesCount: Int)

    public var errorDescription: String? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        switch self {
        case let .cancelled(date):
            return ReadiumLCPLocalizedString("StatusError.cancelled", dateFormatter.string(from: date))

        case let .returned(date):
            return ReadiumLCPLocalizedString("StatusError.returned", dateFormatter.string(from: date))

        case let .expired(start: start, end: end):
            if start > Date() {
                return ReadiumLCPLocalizedString("StatusError.expired.start", dateFormatter.string(from: start))
            } else {
                return ReadiumLCPLocalizedString("StatusError.expired.end", dateFormatter.string(from: end))
            }

        case let .revoked(date, devicesCount):
            return ReadiumLCPLocalizedString("StatusError.revoked", dateFormatter.string(from: date), devicesCount)
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
            return ReadiumLCPLocalizedString("RenewError.renewFailed")
        case .invalidRenewalPeriod(maxRenewDate: _):
            return ReadiumLCPLocalizedString("RenewError.invalidRenewalPeriod")
        case .unexpectedServerError:
            return ReadiumLCPLocalizedString("RenewError.unexpectedServerError")
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
            return ReadiumLCPLocalizedString("ReturnError.returnFailed")
        case .alreadyReturnedOrExpired:
            return ReadiumLCPLocalizedString("ReturnError.alreadyReturnedOrExpired")
        case .unexpectedServerError:
            return ReadiumLCPLocalizedString("ReturnError.unexpectedServerError")
        }
    }
}

/// Errors while parsing the License or Status JSON Documents.
public enum ParsingError: Error {
    // The JSON is malformed and can't be parsed.
    case malformedJSON
    // The JSON is not representing a valid License Document.
    case licenseDocument
    // The JSON is not representing a valid Status Document.
    case statusDocument
    // Invalid Link.
    case link
    // Invalid Encryption.
    case encryption
    // Invalid License Document Signature.
    case signature
    // Invalid URL for link with rel %@.
    case url(rel: String)
}

/// Errors while reading or writing a LCP container (LCPL, EPUB, LCPDF, etc.)
public enum ContainerError: Error {
    // Can't access the container, it's format is wrong.
    case openFailed
    // The file at given relative path is not found in the Container.
    case fileNotFound(String)
    // Can't read the file at given relative path in the Container.
    case readFailed(path: String)
    // Can't write the file at given relative path in the Container.
    case writeFailed(path: String)
}
