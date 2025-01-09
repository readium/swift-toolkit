//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumAdapterGCDWebServer
import ReadiumNavigator
import ReadiumShared
import ReadiumStreamer

#if LCP
    import R2LCPClient
    import ReadiumAdapterLCPSQLite
    import ReadiumLCP
#endif

final class Readium {
    lazy var httpClient: HTTPClient = DefaultHTTPClient()
    lazy var httpServer: HTTPServer = GCDHTTPServer(assetRetriever: assetRetriever)

    lazy var formatSniffer: FormatSniffer = DefaultFormatSniffer()

    lazy var assetRetriever = AssetRetriever(
        httpClient: httpClient
    )

    lazy var publicationOpener = PublicationOpener(
        parser: DefaultPublicationParser(
            httpClient: httpClient,
            assetRetriever: assetRetriever,
            pdfFactory: DefaultPDFDocumentFactory()
        ),
        contentProtections: contentProtections
    )

    #if !LCP
        let contentProtections: [ContentProtection] = []

    #else
        lazy var contentProtections: [ContentProtection] = [
            lcpService.contentProtection(with: lcpAuthentication),
        ]

        lazy var lcpService = LCPService(
            client: LCPClient(),
            licenseRepository: try! LCPSQLiteLicenseRepository(),
            passphraseRepository: try! LCPSQLitePassphraseRepository(),
            assetRetriever: assetRetriever,
            httpClient: httpClient
        )

        lazy var lcpAuthentication: LCPAuthenticating = LCPDialogAuthentication()

        /// Facade to the private R2LCPClient.framework.
        class LCPClient: ReadiumLCP.LCPClient {
            func createContext(jsonLicense: String, hashedPassphrase: LCPPassphraseHash, pemCrl: String) throws -> LCPClientContext {
                try R2LCPClient.createContext(jsonLicense: jsonLicense, hashedPassphrase: hashedPassphrase, pemCrl: pemCrl)
            }

            func decrypt(data: Data, using context: LCPClientContext) -> Data? {
                R2LCPClient.decrypt(data: data, using: context as! DRMContext)
            }

            func findOneValidPassphrase(jsonLicense: String, hashedPassphrases: [LCPPassphraseHash]) -> LCPPassphraseHash? {
                R2LCPClient.findOneValidPassphrase(jsonLicense: jsonLicense, hashedPassphrases: hashedPassphrases)
            }
        }
    #endif
}

extension ReadiumShared.ReadError: UserErrorConvertible {
    func userError() -> UserError {
        UserError(cause: self) {
            switch self {
            case let .access(error):
                return error.userError().message
            case .decoding:
                return "error_decoding".localized
            case .unsupportedOperation:
                return "error_read".localized
            }
        }
    }
}

extension ReadiumShared.AccessError: UserErrorConvertible {
    func userError() -> UserError {
        switch self {
        case let .http(error):
            return error.userError()
        case let .fileSystem(error):
            return error.userError()
        case .other:
            return UserError("error_read".localized, cause: self)
        }
    }
}

extension ReadiumShared.HTTPError: UserErrorConvertible {
    func userError() -> UserError {
        UserError(cause: self) {
            switch self {
            case let .errorResponse(response):
                switch response.status {
                case .notFound:
                    return "error_not_found".localized
                case .unauthorized, .forbidden:
                    return "error_forbidden".localized
                default:
                    return "error_network".localized
                }
            case let .fileSystem(error):
                return error.userError().message
            case .cancelled:
                return "error_cancelled".localized
            case .malformedRequest, .malformedResponse, .timeout, .unreachable, .redirection, .security, .rangeNotSupported, .offline, .other:
                return "error_network".localized
            }
        }
    }
}

extension ReadiumShared.FileSystemError: UserErrorConvertible {
    func userError() -> UserError {
        UserError(cause: self) {
            switch self {
            case .fileNotFound:
                return "error_not_found".localized
            case .forbidden:
                return "error_forbidden".localized
            case .io:
                return "error_io".localized
            }
        }
    }
}

extension ReadiumShared.AssetRetrieveError: UserErrorConvertible {
    func userError() -> UserError {
        UserError(cause: self) {
            switch self {
            case .formatNotSupported:
                return "reader_error_formatNotSupported".localized
            case let .reading(error):
                return error.userError().message
            }
        }
    }
}

extension ReadiumShared.AssetRetrieveURLError: UserErrorConvertible {
    func userError() -> UserError {
        UserError(cause: self) {
            switch self {
            case .schemeNotSupported:
                return "reader_error_schemeNotSupported".localized
            case .formatNotSupported:
                return "reader_error_formatNotSupported".localized
            case let .reading(error):
                return error.userError().message
            }
        }
    }
}

extension ReadiumShared.SearchError: UserErrorConvertible {
    func userError() -> UserError {
        UserError(cause: self) {
            switch self {
            case .publicationNotSearchable, .badQuery:
                return "reader_error_search".localized
            case let .reading(error):
                return error.userError().message
            }
        }
    }
}

extension ReadiumStreamer.PublicationOpenError: UserErrorConvertible {
    func userError() -> UserError {
        UserError(cause: self) {
            switch self {
            case .formatNotSupported:
                return "reader_error_formatNotSupported".localized
            case let .reading(error):
                return error.userError().message
            }
        }
    }
}

extension ReadiumNavigator.NavigatorError: UserErrorConvertible {
    func userError() -> UserError {
        UserError(cause: self) {
            switch self {
            case .copyForbidden:
                return "reader_error_copyForbidden".localized
            }
        }
    }
}

extension ReadiumNavigator.TTSError: UserErrorConvertible {
    func userError() -> UserError {
        UserError(cause: self) {
            switch self {
            case .languageNotSupported:
                return "reader_error_tts_language_not_supported".localized
            case .other:
                return "reader_error_tts".localized
            }
        }
    }
}

#if LCP

    extension LCPError: UserErrorConvertible {
        func userError() -> UserError {
            UserError(cause: self) {
                switch self {
                case .missingPassphrase:
                    return "lcp_error_missing_passphrase".localized
                case .notALicenseDocument, .licenseIntegrity, .licenseProfileNotSupported, .parsing:
                    return "lcp_error_invalid_license".localized
                case .licenseIsBusy, .licenseInteractionNotAvailable:
                    return "lcp_error_invalid_operation".localized
                case .licenseContainer:
                    return "lcp_error_container".localized
                case .crlFetching, .runtime, .unknown:
                    return "lcp_error_internal".localized
                case .network:
                    return "lcp_error_network".localized
                case let .licenseStatus(error):
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .medium

                    switch error {
                    case let .cancelled(date):
                        return "lcp_error_status_cancelled".localized(dateFormatter.string(from: date))
                    case let .returned(date):
                        return "lcp_error_status_returned".localized(dateFormatter.string(from: date))

                    case let .expired(start: start, end: end):
                        if start > Date() {
                            return "lcp_error_status_expired_start".localized(dateFormatter.string(from: start))
                        } else {
                            return "lcp_error_status_expired_end".localized(dateFormatter.string(from: end))
                        }

                    case let .revoked(date, devicesCount):
                        return "lcp_error_status_revoked".localized(dateFormatter.string(from: date), devicesCount)
                    }
                case let .licenseRenew(error):
                    switch error {
                    case .renewFailed:
                        return "lcp_error_renew_failed".localized
                    case .invalidRenewalPeriod:
                        return "lcp_error_invalid_renewal_period".localized
                    case .unexpectedServerError:
                        return "lcp_error_network".localized
                    }
                case let .licenseReturn(error):
                    switch error {
                    case .returnFailed:
                        return "lcp_error_return_failed".localized
                    case .alreadyReturnedOrExpired:
                        return "lcp_error_already_returned_or_expired".localized
                    case .unexpectedServerError:
                        return "lcp_error_network".localized
                    }
                }
            }
        }
    }

#endif
