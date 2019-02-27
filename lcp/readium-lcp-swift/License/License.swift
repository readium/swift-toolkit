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


final class License {

    // Last Documents which passed the integrity checks.
    private var documents: ValidatedDocuments

    // Dependencies
    private let validation: LicenseValidation
    private let licenses: LicensesRepository
    private let device: DeviceService
    private let network: NetworkService
    private weak var interactionDelegate: LCPInteractionDelegate?

    init(documents: ValidatedDocuments, validation: LicenseValidation, licenses: LicensesRepository, device: DeviceService, network: NetworkService, interactionDelegate: LCPInteractionDelegate?) {
        self.documents = documents
        self.validation = validation
        self.licenses = licenses
        self.device = device
        self.network = network
        self.interactionDelegate = interactionDelegate

        validation.observe { [weak self] documents, error in
            if let documents = documents {
                self?.documents = documents
            }
        }
    }

}


/// License activies
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

    /// Calls a Status Document interaction from its `rel`.
    /// The Status Document will be updated with the one returned by the LSD server, after validation.
    fileprivate func callLSDInteraction(_ rel: StatusDocument.Rel, with parameters: [String: CustomStringConvertible] = [:], checkHTTPStatus: @escaping (Int) throws -> Void) -> Deferred<Void> {

        func callPUT(_ url: URL, checkHTTPStatus: @escaping (Int) throws -> Void) -> Deferred<Data> {
            return self.network.fetch(url, method: .put)
                .map { status, data -> Data in
                    try checkHTTPStatus(status)
                    return data
                }
        }
        
        func callHTML(_ url: URL) throws -> Deferred<Data> {
            guard let statusURL = try? self.license.url(for: .status),
                let interactionDelegate = self.interactionDelegate else
            {
                throw LCPError.licenseInteractionNotAvailable
            }

            return Deferred<Void> { success, _ in
                interactionDelegate.presentLCPInteraction(at: url, dismissed: success)
            }
            .flatMap { _ in
                // We fetch the Status Document again after the HTML interaction is done, in case the HTML interaction changed the License.
                self.network.fetch(statusURL)
            }
            .map { status, data in
                try checkHTTPStatus(status)
                return data
            }
        }

        return Deferred<Data> {
            let parameters = parameters.merging(self.device.asQueryParameters, uniquingKeysWith: { first, _ in first })
            guard let status = self.documents.status,
                let link = status.link(for: rel),
                let url = link.url(with: parameters) else
            {
                throw LCPError.licenseInteractionNotAvailable
            }

            if link.type == "text/html" {
                return try callHTML(url)
            } else {
                return callPUT(url, checkHTTPStatus: checkHTTPStatus)
            }
        }
        .flatMap { data in
            // Validates the received updated Status Document.
            self.validation.validate(.status(data))
        }
        .map { _ in () }  // We don't want to forward the Validated Documents
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
    
    func remainingQuantity(for right: LCPRight) -> Int? {
        // FIXME: TODO using database
        return nil
    }
    
    func consume(_ right: LCPRight, quantity: Int) -> Bool {
        // FIXME: TODO
        return true
    }
    
}


/// Shared DRM API
extension License: DRMLicense {

    public var encryptionProfile: String? {
        return license.encryption.profile
    }
    
    public func decipher(_ data: Data) throws -> Data? {
        let context = try documents.getContext()
        return decrypt(data: data, using: context)
    }

    public var loan: DRMLoan? {
        return self
    }

}


/// Loan API
extension License: DRMLoan {
    
    var canReturnLicense: Bool {
        return status?.link(for: .return) != nil
    }
    
    func returnLicense(completion: @escaping (Error?) -> Void) {
        func checkHTTPSTatus(status: Int) throws {
            switch status {
            case 200:
                return
            case 400:
                throw DRMReturnError.returnFailed(message: nil)
            case 403:
                throw DRMReturnError.alreadyReturnedOrExpired
            default:
                throw DRMReturnError.unexpectedServerError(nil)
            }
        }
        
        callLSDInteraction(.return, checkHTTPStatus: checkHTTPSTatus)
            .resolve(completion)
    }
    
    var maxRenewDate: Date? {
        return status?.potentialRights?.end
    }
    
    var canRenewLicense: Bool {
        return status?.link(for: .renew) != nil
    }
    
    func renewLicense(to end: Date?, completion: @escaping (Error?) -> Void) {
        func checkHTTPStatus(status: Int) throws {
            switch status {
            case 200:
                return
            case 400:
                throw DRMRenewError.renewFailed(message: nil)
            case 403:
                throw DRMRenewError.invalidRenewalPeriod(maxRenewDate: maxRenewDate)
            default:
                throw DRMRenewError.unexpectedServerError(nil)
            }
        }
        
        var params: [String: CustomStringConvertible] = [:]
        if let end = end {
            params["end"] = end
        }
        
        callLSDInteraction(.renew, with: params, checkHTTPStatus: checkHTTPStatus)
            .resolve(completion)
    }

}
