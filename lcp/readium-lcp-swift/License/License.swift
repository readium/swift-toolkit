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

        validation.observe { [weak self] documents, error in
            if let documents = documents {
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
        return (charactersToCopyLeft ?? 1) > 0
    }
    
    func copy(_ text: String) -> String? {
        guard var charactersLeft = charactersToCopyLeft else {
            return text
        }
        guard charactersLeft > 0 else {
            return nil
        }
        
        var text = text
        if text.count > charactersLeft {
            // Truncates the text to the amount of characters left.
            let endIndex = text.index(text.startIndex, offsetBy: charactersLeft)
            text = String(text[..<endIndex])
        }
        
        do {
            charactersLeft = max(0, charactersLeft - text.count)
            try licenses.setCopiesLeft(charactersLeft, for: license.id)
        } catch {
            log(.error, error)
        }
        
        return text
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
    
    var canPrint: Bool {
        return (pagesToPrintLeft ?? 1) > 0
    }
    
    func print(pagesCount: Int) -> Bool {
        guard var pagesLeft = pagesToPrintLeft else {
            return true
        }
        guard pagesLeft >= pagesCount else {
            return false
        }
        
        do {
            pagesLeft = max(0, pagesLeft - pagesCount)
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

        func callPUT(_ url: URL) -> Deferred<Data> {
            return self.network.fetch(url, method: .put)
                .map { status, data -> Data in
                    switch status {
                    case 200:
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
        
        func callHTML(_ url: URL) throws -> Deferred<Data> {
            guard let statusURL = try? self.license.url(for: .status) else {
                throw LCPError.licenseInteractionNotAvailable
            }
            
            return Deferred<Void> { success, _ in present(url, success) }
                .flatMap { _ in
                    // We fetch the Status Document again after the HTML interaction is done, in case it changed the License.
                    self.network.fetch(statusURL)
                        .map { status, data in
                            guard status == 200 else {
                                throw LCPError.network(nil)
                            }
                            return data
                        }
                }
        }

        Deferred<Data> {
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
            
            if link.type == "text/html" {
                return try callHTML(url)
            } else {
                return callPUT(url)
            }
        }
        .flatMap(self.validateStatusDocument)
        .resolve(LCPError.wrap(completion))
    }
    
    var canReturnPublication: Bool {
        return status?.link(for: .return) != nil
    }
    
    func returnPublication(completion: @escaping (LCPError?) -> Void) {
        guard let status = self.documents.status,
            let url = try? status.url(for: .return, with: device.asQueryParameters) else
        {
            completion(LCPError.licenseInteractionNotAvailable)
            return
        }
        
        network.fetch(url, method: .put)
            .map { status, data in
                switch status {
                case 200:
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
            .resolve(LCPError.wrap(completion))
    }
    
}


/// Internal API
extension License {

    /// Downloads the publication and return the path to the downloaded resource.
    func fetchPublication(completion: @escaping ((URL, URLSessionDownloadTask?)?, Error?) -> Void) -> Observable<DownloadProgress> {
        do {
            let license = self.documents.license
            let title = license.link(for: .publication)?.title
            let url = try license.url(for: .publication)

            return self.network.download(url, title: title) { result, error in
                guard let (downloadedFile, task) = result else {
                    completion(nil, error)
                    return
                }
                
                do {
                    // Saves the License Document into the downloaded publication
                    let container = EPUBLicenseContainer(epub: downloadedFile)
                    try container.write(license)
                    completion((downloadedFile, task), nil)
                    
                } catch {
                    completion(nil, error)
                }
            }
            
        } catch {
            DispatchQueue.main.async {
                completion(nil, error)
            }
            return Observable<DownloadProgress>(.infinite)
        }
    }
    
    /// Shortcut to be used in LSD interactions (eg. renew), to validate the returned Status Document.
    fileprivate func validateStatusDocument(data: Data) -> Deferred<Void> {
        return validation.validate(.status(data))
            .map { _ in () }  // We don't want to forward the Validated Documents
    }

}
