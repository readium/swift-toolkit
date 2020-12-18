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
import R2LCPClient
import R2Shared


final class License: Loggable {

    // Last Documents which passed the integrity checks.
    private var documents: ValidatedDocuments

    // Dependencies
    private let validation: LicenseValidation
    private let licenses: LicensesRepository
    private let device: DeviceService
    private let network: NetworkService

    init(documents: ValidatedDocuments, validation: LicenseValidation, licenses: LicensesRepository, device: DeviceService, network: NetworkService) {
        self.documents = documents
        self.validation = validation
        self.licenses = licenses
        self.device = device
        self.network = network

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
        return decrypt(data: data, using: context)
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
    
    func renewLoan(to end: Date?, present: @escaping URLPresenter, completion: @escaping (LCPError?) -> Void) {

        func callPUT(_ url: URL) -> Deferred<Data, Error> {
            return self.network.fetch(url, method: .put)
                .tryMap { status, data -> Data in
                    switch status {
                    case 100..<400:
                        break
                    case 400:
                        throw RenewError.renewFailed
                    case 403:
                        throw RenewError.invalidRenewalPeriod(maxRenewDate: self.maxRenewDate)
                    default:
                        throw RenewError.unexpectedServerError
                    }
                    return data
                }
        }
        
        func callHTML(_ url: URL) throws -> Deferred<Data, Error> {
            guard let statusURL = try? self.license.url(for: .status, preferredType: .lcpStatusDocument) else {
                throw LCPError.licenseInteractionNotAvailable
            }
            
            return deferred { success, _, _ in present(url, { success(()) }) }
                .flatMap { _ in
                    // We fetch the Status Document again after the HTML interaction is done, in case it changed the License.
                    self.network.fetch(statusURL)
                        .tryMap { status, data in
                            guard 100..<400 ~= status else {
                                throw LCPError.network(nil)
                            }
                            return data
                        }
                }
        }

        deferredCatching {
            var params = self.device.asQueryParameters
            if let end = end {
                params["end"] = end.iso8601
            }
            
            guard let status = self.documents.status,
                let link = status.link(for: .renew),
                let url = link.url(with: params) else
            {
                throw LCPError.licenseInteractionNotAvailable
            }
            
            if link.mediaType.isHTML {
                return try callHTML(url)
            } else {
                return callPUT(url)
            }
        }
        .flatMap(self.validateStatusDocument)
        .mapError(LCPError.wrap)
        .resolveWithError(completion)
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
        
        network.fetch(url, method: .put)
            .tryMap { status, data in
                switch status {
                case 100..<400:
                    break
                case 400:
                    throw ReturnError.returnFailed
                case 403:
                    throw ReturnError.alreadyReturnedOrExpired
                default:
                    throw ReturnError.unexpectedServerError
                }
                return data
            }
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
