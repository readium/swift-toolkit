//
//  License.swift
//  readium-lcp-swift
//
//  Created by Mickaël Menu on 08.02.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import ZIPFoundation
import R2Shared


final class License: Loggable {

    // Last Documents which passed the integrity checks.
    private var documents: ValidatedDocuments

    // Dependencies
    private let client: LCPClient
    private let validation: LicenseValidation
    private let licenses: LicensesRepository
    private let device: DeviceService
    private let httpClient: HTTPClient

    init(documents: ValidatedDocuments, client: LCPClient, validation: LicenseValidation, licenses: LicensesRepository, device: DeviceService, httpClient: HTTPClient) {
        self.documents = documents
        self.client = client
        self.validation = validation
        self.licenses = licenses
        self.device = device
        self.httpClient = httpClient

        validation.observe { [weak self] result in
            if case .success(let documents) = result {
                self?.documents = documents
            }
        }
    }

}


/// Public API
extension License: LCPLicense {
    
    public var license: LicenseDocument {
        return documents.license
    }
    
    public var status: StatusDocument? {
        return documents.status
    }
    
    public var encryptionProfile: String? {
        return license.encryption.profile
    }
    
    public func decipher(_ data: Data) throws -> Data? {
        let context = try documents.getContext()
        return client.decrypt(data: data, using: context)
    }
    
    var charactersToCopyLeft: Int? {
        do {
            if let charactersLeft = try licenses.copiesLeft(for: license.id) {
                return charactersLeft
            }
        } catch {
            log(.error, error)
        }
        return nil
    }
    
    var canCopy: Bool {
        (charactersToCopyLeft ?? 1) > 0
    }
    
    func canCopy(text: String) -> Bool {
        guard let charactersLeft = charactersToCopyLeft else {
            return true
        }
        return text.count <= charactersLeft
    }
    
    func copy(text: String) -> Bool {
        guard var charactersLeft = charactersToCopyLeft else {
            return true
        }
        guard text.count <= charactersLeft else {
            return false
        }
        
        do {
            charactersLeft = max(0, charactersLeft - text.count)
            try licenses.setCopiesLeft(charactersLeft, for: license.id)
        } catch {
            log(.error, error)
        }
        
        return true
    }
    
    // Deprecated
    func copy(_ text: String, consumes: Bool) -> String? {
        if consumes {
            return copy(text: text) ? text : nil
        } else {
            return canCopy(text: text) ? text : nil
        }
    }
    
    var pagesToPrintLeft: Int? {
        do {
            if let pagesLeft = try licenses.printsLeft(for: license.id) {
                return pagesLeft
            }
        } catch {
            log(.error, error)
        }
        return nil
    }
    
    func canPrint(pageCount: Int) -> Bool {
        guard let pagesLeft = pagesToPrintLeft else {
            return true
        }
        return pageCount <= pagesLeft
    }
    
    var canPrint: Bool {
        (pagesToPrintLeft ?? 1) > 0
    }
    
    func print(pageCount: Int) -> Bool {
        guard var pagesLeft = pagesToPrintLeft else {
            return true
        }
        guard pagesLeft >= pageCount else {
            return false
        }
        
        do {
            pagesLeft = max(0, pagesLeft - pageCount)
            try licenses.setPrintsLeft(pagesLeft, for: license.id)
        } catch {
            log(.error, error)
        }
        return true
    }
    
    var canRenewLoan: Bool {
        return status?.link(for: .renew) != nil
    }
    
    var maxRenewDate: Date? {
        return status?.potentialRights?.end
    }

    func renewLoan(with delegate: LCPRenewDelegate, prefersWebPage: Bool, completion: @escaping (CancellableResult<(), LCPError>) -> ()) {

        func renew() -> Deferred<Data, Error> {
            deferredCatching {
                guard let link = findRenewLink() else {
                    throw LCPError.licenseInteractionNotAvailable
                }

                if link.mediaType.isHTML {
                    return try renewWithWebPage(link)
                } else {
                    return renewProgrammatically(link)
                }
            }
        }

        // Finds the renew link according to `prefersWebPage`.
        func findRenewLink() -> Link? {
            guard let status = self.documents.status else {
                return nil
            }

            var types = [MediaType.html, MediaType.xhtml]
            if (prefersWebPage) {
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
        func renewWithWebPage(_ link: Link) throws -> Deferred<Data, Error> {
            guard
                let statusURL = try? self.license.url(for: .status, preferredType: .lcpStatusDocument),
                let url = link.url
            else {
                throw LCPError.licenseInteractionNotAvailable
            }

            return delegate.presentWebPage(url: url)
                .flatMap {
                    // We fetch the Status Document again after the HTML interaction is done, in case it changed the
                    // License.
                    self.httpClient.fetch(statusURL)
                        .map { $0.body ?? Data() }
                        .eraseToAnyError()
                }
        }

        // Programmatically renew the loan with a PUT request.
        func renewProgrammatically(_ link: Link) -> Deferred<Data, Error> {

            // Asks the delegate for a renew date if there's an `end` parameter.
            func preferredEndDate() -> Deferred<Date?, Error> {
                (link.templateParameters.contains("end"))
                    ? delegate.preferredEndDate(maximum: maxRenewDate)
                    : Deferred.success(nil)
            }

            func makeRenewURL(from endDate: Date?) throws -> URL {
                var params = device.asQueryParameters
                if let end = endDate {
                    params["end"] = end.iso8601
                }

                guard let url = link.url(with: params) else {
                    throw LCPError.licenseInteractionNotAvailable
                }
                return url
            }

            return preferredEndDate()
                .tryMap(makeRenewURL(from:))
                .flatMap {
                    self.httpClient.fetch(HTTPRequest(url: $0, method: .put))
                        .map { $0.body ?? Data() }
                        .mapError { error -> RenewError in
                            switch error.kind {
                            case .badRequest:
                                return .renewFailed
                            case .forbidden:
                                return .invalidRenewalPeriod(maxRenewDate: self.maxRenewDate)
                            default:
                                return .unexpectedServerError
                            }
                        }
                        .eraseToAnyError()
                }
        }

        renew()
            .flatMap(validateStatusDocument)
            .mapError(LCPError.wrap)
            .resolve { result in
                // Trick to make sure the delegate is not deallocated before the end of the renew process.
                _ = type(of: delegate)

                completion(result)
            }
    }
    
    var canReturnPublication: Bool {
        return status?.link(for: .return) != nil
    }
    
    func returnPublication(completion: @escaping (LCPError?) -> Void) {
        guard let status = self.documents.status,
            let url = try? status.url(for: .return, preferredType: .lcpStatusDocument, with: device.asQueryParameters) else
        {
            completion(LCPError.licenseInteractionNotAvailable)
            return
        }
        
        httpClient.fetch(HTTPRequest(url: url, method: .put))
            .mapError { error -> ReturnError in
                switch error.kind {
                case .badRequest:
                    return .returnFailed
                case .forbidden:
                    return .alreadyReturnedOrExpired
                default:
                    return .unexpectedServerError
                }
            }
            .map { $0.body ?? Data() }
            .flatMap(validateStatusDocument)
            .mapError(LCPError.wrap)
            .resolveWithError(completion)
    }

    /// Shortcut to be used in LSD interactions (eg. renew), to validate the returned Status Document.
    fileprivate func validateStatusDocument(data: Data) -> Deferred<Void, Error> {
        return validation.validate(.status(data))
            .map { _ in () }  // We don't want to forward the Validated Documents
    }

}

extension LCPRenewDelegate {

    public func preferredEndDate(maximum: Date?) -> Deferred<Date?, Error> {
        Deferred { preferredEndDate(maximum: maximum, completion: $0) }
    }

    public func presentWebPage(url: URL) -> Deferred<Void, Error> {
        Deferred { presentWebPage(url: url, completion: $0) }
    }

}
