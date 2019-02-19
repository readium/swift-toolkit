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
import UIKit
import ZIPFoundation
import R2LCPClient
import R2Shared

private let DEBUG = true


final class License {

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


/// License activies
extension License {

    /// Downloads the publication and return the path to the downloaded resource.
    func fetchPublication() -> Deferred<(URL, URLSessionDownloadTask?)> {
        return Deferred {
            let license = self.documents.license
            let title = license.link(for: .publication)?.title
            let url = try license.url(for: .publication)

            return self.network.download(url, title: title)
                .map { downloadedFile, task in
                    // Saves the License Document into the downloaded publication
                    let container = EPUBLicenseContainer(epub: downloadedFile)
                    try container.write(license)

                    // FIXME: don't move to Documents/ keep it as a temp dir and let the client app choose where to move the file
                    // FIXME: support other kind of publication extensions, using mimetype
                    let fileManager = FileManager.default
                    let destinationFile = try! fileManager
                        .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                        .appendingPathComponent("lcp.\(license.id).epub")

                    // FIXME: for now we overwrite the destination file, but this needs to be handled on the test app
                    try? fileManager.removeItem(at: destinationFile)
                    try fileManager.moveItem(at: downloadedFile, to: destinationFile)

                    return (destinationFile, task)
                }
            }
    }

    /// Calls a Status Document interaction from its `rel`.
    /// The Status Document will be updated with the one returned by the LSD server, after validation.
    fileprivate func callLSDInteraction(_ rel: StatusDocument.Rel, check: @escaping (Int) throws -> Void) -> Deferred<Void> {
        return Deferred {
            guard let status = self.documents.status,
                let url = try? status.url(for: rel, with: self.device.asQueryParameters) else
            {
                throw LCPError.licenseInteractionNotAvailable
            }

            return self.network.fetch(url, method: .put)
                .map { status, data -> Data in
                    try check(status)
                    return data
                }
                .flatMap { data in
                    // Updates the returned Status Document, after validation
                    self.validation.validate(.status(data))
                        .map { _ in () }  // We don't want to forward the validated documents
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

    public var rights: DRMRights? {
        return self
    }
    
    public var loan: DRMLoan? {
        return self
    }

}


/// Rights API
extension License: DRMRights {
    
    func can(_ right: DRMRight) -> Bool {
        switch right {
        case .display:
            let now = Date()
            let start = license.rights.start ?? now
            let end = license.rights.end ?? now
            return start <= now && now <= end
        default:
            return true
        }
    }
    
    func remainingQuantity(for right: DRMConsumableRight) -> DRMRightQuantity {
        // FIXME: TODO using database
        return .unlimited
    }
    
    func consume(_ right: DRMConsumableRight, quantity: DRMRightQuantity?) throws {
        // FIXME: TODO
    }

}


/// Loan API
extension License: DRMLoan {
    
    var canReturnLicense: Bool {
        return status?.link(for: .return) != nil
    }
    
    func returnLicense(completion: @escaping (Error?) -> Void) {
        func check(status: Int) throws {
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
        
        callLSDInteraction(.return, check: check)
            .resolve(completion)
    }
    
    var maxRenewDate: Date? {
        return status?.potentialRights?.end
    }
    
    var canRenewLicense: Bool {
        return status?.link(for: .renew) != nil
    }
    
    func renewLicense(to end: Date?, completion: @escaping (Error?) -> Void) {
        func check(status: Int) throws {
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
        
        callLSDInteraction(.renew, check: check)
            .resolve(completion)
    }

}
