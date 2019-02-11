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
import SwiftyJSON
import ZIPFoundation
import R2Shared
import R2LCPClient

private let DEBUG = true


final class License {

    // Dependencies
    private let container: LicenseContainer
    private let validation: LicenseValidation
    private let device: DeviceService
    private let network: NetworkService

    init(container: LicenseContainer, validation: LicenseValidation, device: DeviceService, network: NetworkService) {
        self.container = container
        self.validation = validation
        self.device = device
        self.network = network
        
        // Updates the documents once the integrity is checked.
        validation.observe { [weak self] documents, error in
            if let documents = documents {
                self?.documents = documents
            }
        }
    }

    // Last validated License and Status documents.
    private var documents: ValidatedDocuments? {
        didSet {
            // Overwrites the License Document in the container if it was updated
            if let newLicense = documents?.license, containerLicenseData != newLicense.data {
                if (DEBUG) { print("#license Write updated License Document in container") }
                try? self.container.write(newLicense) // FIXME: should we report an error here?
            }
        }
    }
    
    // Used to check if we need to update the license in the container.
    private var containerLicenseData: Data?

}


/// License activies
extension License {
    
    /// Reads and validates the License Document in the container, if needed.
    func open() -> Deferred<Void> {
        return Deferred {
            guard self.documents == nil else {
                throw LCPError.runtime("\(type(of: self)): A License can only be opened once")
            }
            guard let data = try? self.container.read() else {
                throw LCPError.licenseNotInContainer  // FIXME: wrong error?
            }
            
            self.containerLicenseData = data
            
            return self.validation.validate(.license(data))
                .map { documents in
                    // Forwards any status error (eg. revoked)
                    try documents.checkStatus()
                }
        }
    }
    
    /// Downloads the publication and return the path to the downloaded resource.
    func fetchPublication() -> Deferred<(URL, URLSessionDownloadTask?)> {
        return Deferred {
            guard let license = self.documents?.license else {
                throw LCPError.runtime("\(type(of: self)): Can't fetch the publication of a License pending validation")
            }
            guard let link = license.link(withRel: LicenseDocument.Rel.publication) else {
                throw LCPError.publicationLinkNotFound
            }

            return self.network.download(link.href, description: link.title)
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
    fileprivate func callLSDInteraction(_ rel: StatusDocument.Rel, errors: [Int: LCPError] = [:]) -> Deferred<Void> {
        return Deferred {
            guard let documents = self.documents else {
                throw LCPError.runtime("\(type(of: self)): Can't call an LSD interaction on a License pending validation")
            }
            try documents.checkStatus()
            
            guard let status = documents.status else {
                throw LCPError.noStatusDocument
            }

            guard let link = status.link(withRel: rel),
                  let url = self.network.urlFromLink(link, context: self.device.asQueryParameters)
            else {
                throw LCPError.statusLinkNotFound(rel.rawValue)
            }
    
            return self.network.fetch(url, method: .put)
                .map { status, data -> Data in
                    guard status == 200 else {
                        throw errors[status] ?? LCPError.unexpectedServerError
                    }
    
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

    /// Decipher encrypted content.
    public func decipher(_ data: Data) throws -> Data? {
        guard let context = documents?.context else {
            throw LCPError.runtime("\(type(of: self)): Can't decipher using a License pending validation")
        }
        return decrypt(data: data, using: context)
    }

    public func areRightsValid() throws {
        // FIXME: to remove? this is done in the License Integrity check per the specification
    }

    public func register() {
        // FIXME: to remove? this is a DRM-specific concern and shouldn't leak into the client app
    }

    public func renew(endDate: Date?, completion: @escaping (Error?) -> Void) {
        callLSDInteraction(.renew, errors: [
            400: .renewFailure,
            403: .renewPeriod,
        ]).resolve(completion)
    }

    public func `return`(completion: @escaping (Error?) -> Void){
        callLSDInteraction(.return, errors: [
            400: .returnFailure,
            403: .alreadyReturned,
        ])
        .resolve(completion)
        // FIXME: I expect the returned Status Document to have a "revoked" status, which will be returned to the caller as an error. Maybe we should catch this specific error and consider that it's actually a success?
    }

    public func currentStatus() -> String {
        return documents?.status?.status.rawValue ?? ""
    }

    public func lastUpdate() -> Date {
        return documents?.license.dateOfLastUpdate() ?? Date(timeIntervalSinceReferenceDate: 0)
    }

    public func issued() -> Date {
        return documents?.license.issued ?? Date(timeIntervalSinceReferenceDate: 0)
    }

    public func provider() -> URL {
        return documents?.license.provider ?? URL(fileURLWithPath: "/")
    }

    public func rightsEnd() -> Date? {
        return documents?.license.rights.end
    }

    public func potentialRightsEnd() -> Date? {
        return documents?.license.rights.potentialEnd
    }

    public func rightsStart() -> Date? {
        return documents?.license.rights.start
    }

    public func rightsPrints() -> Int? {
        return documents?.license.rights.print
    }

    public func rightsCopies() -> Int? {
        return documents?.license.rights.copy
    }

    public var profile: String {
        return documents?.license.encryption.profile.absoluteString ?? ""
    }
    
}
