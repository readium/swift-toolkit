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

    // Result of the last validation.
    private var state: State

    // Dependencies
    private let container: LicenseContainer
    private let validation: LicenseValidation
    private let licenses: LicensesRepository
    private let device: DeviceService
    private let network: NetworkService

    init(container: LicenseContainer, validation: LicenseValidation, licenses: LicensesRepository, device: DeviceService, network: NetworkService) {
        self.state = .invalid(.runtime("The License is pending validation"))
        self.container = container
        self.validation = validation
        self.licenses = licenses
        self.device = device
        self.network = network

        validation.delegate = self
        validation.observe { [weak self] documents, error in
            if let (license, context, status) = documents {
                self?.state = .valid(license, context, status)
            } else {
                self?.state = .invalid(.wrap(error))
            }
        }
    }
    
    fileprivate enum State {
        case valid(LicenseDocument, DRMContext, StatusDocument?)
        case invalid(LCPError)
        
        /// Accesses the validated Documents and context, or throws the validation error.
        func get() throws -> (license: LicenseDocument, context: DRMContext, status: StatusDocument?) {
            switch self {
            case let .valid(license, context, status):
                return (license, context, status)
            case let .invalid(error):
                throw error
            }
        }
    }

}


extension License: LicenseValidationDelegate {
    
    func didValidateIntegrity(of license: LicenseDocument, updated: Bool) throws {
        // FIXME: Should we forward the errors here? This would block the validation.
        
        try? licenses.addOrUpdateLicense(license)
        
        // Updates the License Document in its container if it was updated.
        if (updated) {
            do {
                try self.container.write(license)
                if (DEBUG) { print("#license Wrote updated License Document in container") }
            } catch {
                if (DEBUG) { print("#license Failed to write updated License Document in container: \(error)") }
            }
        }
    }
    
}


/// License activies
extension License {
    
    /// Reads and validates the License Document in the container.
    /// Returns itself to apply more transformations on the License.
    func evaluate() -> Deferred<License> {
        return Deferred {
            let data = try self.container.read()
            return self.validation.validate(.license(data))
                .map { _ in self }
        }
    }
    
    /// Downloads the publication and return the path to the downloaded resource.
    func fetchPublication() -> Deferred<(URL, URLSessionDownloadTask?)> {
        return Deferred {
            let license = try self.state.get().license
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
    fileprivate func callLSDInteraction(_ rel: StatusDocument.Rel, errors: [Int: InteractionError] = [:]) -> Deferred<Void> {
        return Deferred {
            guard let status = try self.state.get().status,
                let url = try? status.url(for: rel, with: self.device.asQueryParameters) else
            {
                throw InteractionError.notAvailable
            }

            return self.network.fetch(url, method: .put)
                .map { status, data -> Data in
                    guard status == 200 else {
                        throw errors[status] ?? InteractionError.unexpectedServerError
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
        let context = try state.get().context
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
            400: .renewFailed,
            403: .invalidRenewalPeriod,
        ]).resolve(completion)
    }

    public func `return`(completion: @escaping (Error?) -> Void){
        callLSDInteraction(.return, errors: [
            400: .returnFailed,
            403: .alreadyReturnedOrExpired,
        ])
        .catch { error in
            // If the return is successful, then the validation will fail with a "returned" StatusError. We catch it as it should be considered a success.
            guard case StatusError.returned = error else {
                throw error
            }
            return ()
        }
        .resolve(completion)
    }

    public func currentStatus() -> String {
        let status = try? state.get().status
        return status??.status.rawValue ?? ""
    }

    public func lastUpdate() -> Date {
        let license = try? state.get().license
        return license?.updated ?? Date(timeIntervalSinceReferenceDate: 0)
    }

    public func issued() -> Date {
        let license = try? state.get().license
        return license?.issued ?? Date(timeIntervalSinceReferenceDate: 0)
    }

    public func provider() -> URL {
        let license = try? state.get().license
        guard let providerString = license?.provider,
            let provider = URL(string: providerString) else {
            return URL(fileURLWithPath: "/")
        }
        return provider
    }

    public func rightsEnd() -> Date? {
        let license = try? state.get().license
        return license?.rights.end
    }

    public func potentialRightsEnd() -> Date? {
        let status = try? state.get().status
        return status??.potentialRights?.end
    }

    public func rightsStart() -> Date? {
        let license = try? state.get().license
        return license?.rights.start
    }

    public func rightsPrints() -> Int? {
        let license = try? state.get().license
        return license?.rights.print
    }

    public func rightsCopies() -> Int? {
        let license = try? state.get().license
        return license?.rights.copy
    }

    public var profile: String {
        let license = try? state.get().license
        return license?.encryption.profile ?? ""
    }
    
}
