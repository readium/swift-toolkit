//
//  Copyright 2024 Readium Foundation. All rights reserved.
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
            licenseRepository: LCPSQLiteLicenseRepository(),
            passphraseRepository: LCPSQLitePassphraseRepository(),
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
            switch kind {
            case .malformedRequest, .malformedResponse, .timeout, .badRequest, .clientError, .serverError, .serverUnreachable, .offline, .other:
                return "error_network".localized
            case .unauthorized, .forbidden:
                return "error_forbidden".localized
            case .notFound:
                return "error_not_found".localized
            case let .fileSystem(error):
                return error.userError().message
            case .cancelled:
                return "error_cancelled".localized
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
