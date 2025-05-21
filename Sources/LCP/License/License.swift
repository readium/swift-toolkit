//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
import ReadiumZIPFoundation

final class License: Loggable {
    // Last Documents which passed the integrity checks.
    private var documents: ValidatedDocuments

    // Dependencies
    private let client: LCPClient
    private let validation: LicenseValidation
    private let licenses: LCPLicenseRepository
    private let device: DeviceService
    private let httpClient: HTTPClient

    init(documents: ValidatedDocuments, client: LCPClient, validation: LicenseValidation, licenses: LCPLicenseRepository, device: DeviceService, httpClient: HTTPClient) {
        self.documents = documents
        self.client = client
        self.validation = validation
        self.licenses = licenses
        self.device = device
        self.httpClient = httpClient

        validation.observe { [weak self] result in
            if case let .success(documents) = result, let documents = documents {
                self?.documents = documents
            }
        }
    }
}

/// Public API
extension License: LCPLicense {
    public var license: LicenseDocument {
        documents.license
    }

    public var status: StatusDocument? {
        documents.status
    }

    public var encryptionProfile: String? {
        license.encryption.profile
    }

    public func decipher(_ data: Data) throws -> Data? {
        let context = try documents.getContext()
        return client.decrypt(data: data, using: context)
    }

    func charactersToCopyLeft() async -> Int? {
        do {
            return try await licenses.userRights(for: license.id).copy
        } catch {
            log(.error, error)
            return nil
        }
    }

    func canCopy(text: String) async -> Bool {
        guard let charactersLeft = await charactersToCopyLeft() else {
            return true
        }
        return text.count <= charactersLeft
    }

    func copy(text: String) async -> Bool {
        do {
            var allowed = true
            try await licenses.updateUserRights(for: license.id) { rights in
                guard let copyLeft = rights.copy else {
                    return
                }
                guard text.count <= copyLeft else {
                    allowed = false
                    return
                }

                rights.copy = max(0, copyLeft - text.count)
            }

            return allowed

        } catch {
            log(.error, error)
            return false
        }
    }

    func pagesToPrintLeft() async -> Int? {
        do {
            return try await licenses.userRights(for: license.id).print
        } catch {
            log(.error, error)
            return nil
        }
    }

    func canPrint(pageCount: Int) async -> Bool {
        guard let pageLeft = await pagesToPrintLeft() else {
            return true
        }
        return pageCount <= pageLeft
    }

    func print(pageCount: Int) async -> Bool {
        do {
            var allowed = true
            try await licenses.updateUserRights(for: license.id) { rights in
                guard let printLeft = rights.print else {
                    return
                }
                guard pageCount <= printLeft else {
                    allowed = false
                    return
                }

                rights.copy = max(0, printLeft - pageCount)
            }

            return allowed

        } catch {
            log(.error, error)
            return false
        }
    }

    var canRenewLoan: Bool {
        status?.link(for: .renew) != nil
    }

    var maxRenewDate: Date? {
        status?.potentialRights?.end
    }

    func renewLoan(with delegate: any LCPRenewDelegate, prefersWebPage: Bool) async -> Result<Void, LCPError> {
        func renew() async throws -> Data {
            guard let link = findRenewLink() else {
                throw LCPError.licenseInteractionNotAvailable
            }

            if link.mediaType?.isHTML == true {
                return try await renewWithWebPage(link)
            } else {
                return try await renewProgrammatically(link)
            }
        }

        // Finds the renew link according to `prefersWebPage`.
        func findRenewLink() -> Link? {
            guard let status = documents.status else {
                return nil
            }

            var types = [MediaType.html, MediaType.xhtml]
            if prefersWebPage {
                types.append(.lcpStatusDocument)
            } else {
                types.insert(.lcpStatusDocument, at: 0)
            }

            for type in types {
                if let link = status.link(for: .renew, type: type) {
                    return link
                }
            }

            // Fallback on the first renew link with no media type set and assume it's a PUT action.
            return status.linkWithNoType(for: .renew)
        }

        // Renew the loan by presenting a web page to the user.
        func renewWithWebPage(_ link: Link) async throws -> Data {
            guard
                let statusURL = try? license.url(for: .status, preferredType: .lcpStatusDocument),
                let url = link.url()
            else {
                throw LCPError.licenseInteractionNotAvailable
            }

            try await delegate.presentWebPage(url: url)

            // We fetch the Status Document again after the HTML interaction is
            // done, in case it changed the License.
            return try await httpClient
                .fetch(HTTPRequest(url: statusURL, headers: ["Accept": MediaType.lcpStatusDocument.string]))
                .map { $0.body ?? Data() }
                .get()
        }

        // Programmatically renew the loan with a PUT request.
        func renewProgrammatically(_ link: Link) async throws -> Data {
            // Asks the delegate for a renew date if there's an `end` parameter.
            func preferredEndDate() async throws -> Date? {
                (link.templateParameters.contains("end"))
                    ? try await delegate.preferredEndDate(maximum: maxRenewDate)
                    : nil
            }

            func makeRenewURL(from endDate: Date?) throws -> HTTPURL {
                var params = device.asQueryParameters
                if let end = endDate {
                    params["end"] = end.iso8601
                }

                guard let url = link.url(parameters: params) else {
                    throw LCPError.licenseInteractionNotAvailable
                }
                return url
            }

            let url = try await makeRenewURL(from: preferredEndDate())

            return try await httpClient.fetch(HTTPRequest(url: url, method: .put))
                .map { $0.body ?? Data() }
                .mapError { error -> RenewError in
                    switch error {
                    case let .errorResponse(response):
                        switch response.status {
                        case .badRequest:
                            return .renewFailed
                        case .forbidden:
                            return .invalidRenewalPeriod(maxRenewDate: self.maxRenewDate)
                        default:
                            return .unexpectedServerError(error)
                        }
                    default:
                        return .unexpectedServerError(error)
                    }
                }
                .get()
        }

        do {
            try await validateStatusDocument(data: renew())
            return .success(())
        } catch {
            return .failure(.wrap(error))
        }
    }

    var canReturnPublication: Bool {
        status?.link(for: .return) != nil
    }

    func returnPublication() async -> Result<Void, LCPError> {
        guard
            let status = documents.status,
            let url = try? status.url(
                for: .return,
                preferredType: .lcpStatusDocument,
                parameters: device.asQueryParameters
            )
        else {
            return .failure(.licenseInteractionNotAvailable)
        }

        do {
            let data = try await httpClient.fetch(HTTPRequest(url: url, method: .put))
                .mapError { error -> ReturnError in
                    switch error {
                    case let .errorResponse(response):
                        switch response.status {
                        case .badRequest:
                            return .returnFailed
                        case .forbidden:
                            return .alreadyReturnedOrExpired
                        default:
                            return .unexpectedServerError(error)
                        }
                    default:
                        return .unexpectedServerError(error)
                    }
                }
                .map { $0.body ?? Data() }
                .get()

            try await validateStatusDocument(data: data)
            return .success(())

        } catch {
            return .failure(.wrap(error))
        }
    }

    /// Shortcut to be used in LSD interactions (eg. renew), to validate the returned Status Document.
    fileprivate func validateStatusDocument(data: Data) async throws {
        _ = try await validation.validate(.status(data))
    }
}
