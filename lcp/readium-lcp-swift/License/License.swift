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

final class License {
    
    enum State {
        case pendingValidation
        case validating(LicenseValidation)
        case valid(LicenseDocument, StatusDocument?, DRMContext)
        case invalid(LCPError)
    }

    private let container: LicenseContainer
    private let makeValidation: () -> LicenseValidation
    private let device: DeviceService
    private let network: NetworkService
    private var state: State

    init(container: LicenseContainer, makeValidation: @escaping () -> LicenseValidation, device: DeviceService, network: NetworkService) {
        self.container = container
        self.makeValidation = makeValidation
        self.device = device
        self.network = network
        self.state = .pendingValidation
    }
    
    /// Reads and validates the License Document in the container.
    func validate(_ completion: @escaping (Result<License>) -> Void) {
        guard let containerLicenseData = try? container.read() else {
            completion(.failure(.licenseNotInContainer)) // FIXME: wrong error?
            return
        }
        
        let validation = makeValidation()
        state = .validating(validation)
        
        deferred { validation.validateLicenseData(containerLicenseData, $0) }
            .map { (license, status, context) -> License in
                // FIXME: Is it useful? it seems to be checked by the lcplib (LCPClientError.licenseOutOfDate)
                try self.areRightsValid()
                
                self.state = .valid(license, status, context)
                // Overwrites the License Document in the container if it was updated
                if containerLicenseData != license.data {
                    try? self.container.write(license) // FIXME: should we report an error here?
                }
                
                return self
            }
            .catch { error in
                self.state = .invalid(error)
                throw error  // forwards the error to the completion handler
            }
            .resolve(completion)
    }
    
    fileprivate func updateStatus(from data: Data, _ completion: @escaping (Result<Void>) -> Void) {
        completion(.success(()))
    }

    fileprivate var license: LicenseDocument? {
        guard case .valid(let license, _, _) = state else {
            return nil
        }
        return license
    }
    
    fileprivate var status: StatusDocument? {
        guard case .valid(_, let optionalStatus, _) = state, let status = optionalStatus else {
            return nil
        }
        return status
    }

    /// Downloads the publication and return the path to the downloaded resource.
    func fetchPublication(_ completion: @escaping (Result<(URL, URLSessionDownloadTask?)>) -> Void) {
        guard case .valid(let license, _, _) = state else {
            completion(.failure(.invalidLicense(nil)))
            return
        }
        
        guard let link = license.link(withRel: LicenseDocument.Rel.publication) else {
            completion(.failure(.publicationLinkNotFound))
            return
        }
        
        deferred { self.network.download(link.href, description: link.title, $0) }
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
                
                try fileManager.moveItem(at: downloadedFile, to: destinationFile)
                
                return (destinationFile, task)
            }
            .resolve(completion)
    }
    
    /// Calls a Status Document interaction from its `rel`.
    /// The Status Document will be updated (and validated) with the one returned by the LSD server.
    fileprivate func callInteraction(_ rel: StatusDocument.Rel, errors: [Int: LCPError] = [:], _ completion: @escaping (Result<Void>) -> Void) {
        guard let status = status else {
            completion(.failure(.noStatusDocument))
            return
        }
        
        guard let link = status.link(withRel: .renew),
            let url = network.makeURL(link, parameters: device.asQueryParameters)
            else {
                completion(.failure(.statusLinkNotFound))
                return
        }
        
        deferred { self.network.fetch(url, method: .put, $0) }
            .map { status, data -> Data in
                guard status == 200 else {
                    throw errors[status] ?? LCPError.unexpectedServerError
                }
                
                return data
            }
            .map { data, completion in
                self.updateStatus(from: data, completion)
            }
            .resolve(completion)
    }

}


/// Public API
extension License: LCPLicense {

    /// Decipher encrypted content.
    public func decipher(_ data: Data) throws -> Data? {
        guard case let .valid(_, _, context) = state else {
            throw LCPError.invalidContext
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
        callInteraction(.renew, errors: [
            400: .renewFailure,
            403: .renewPeriod,
        ]) { completion($0.error) }
    }

    public func `return`(completion: @escaping (Error?) -> Void){
        callInteraction(.return, errors: [
            400: .returnFailure,
            403: .alreadyReturned,
        ]) { completion($0.error) }
    }

    public func currentStatus() -> String {
        return status?.status.rawValue ?? ""
    }

    public func lastUpdate() -> Date {
        return license?.dateOfLastUpdate() ?? Date(timeIntervalSinceReferenceDate: 0)
    }

    public func issued() -> Date {
        return license?.issued ?? Date(timeIntervalSinceReferenceDate: 0)
    }

    public func provider() -> URL {
        return license?.provider ?? URL(fileURLWithPath: "/")
    }

    public func rightsEnd() -> Date? {
        return license?.rights.end
    }

    public func potentialRightsEnd() -> Date? {
        return license?.rights.potentialEnd
    }

    public func rightsStart() -> Date? {
        return license?.rights.start
    }

    public func rightsPrints() -> Int? {
        return license?.rights.print
    }

    public func rightsCopies() -> Int? {
        return license?.rights.copy
    }

    public var profile: String {
        return license?.encryption.profile.absoluteString ?? ""
    }
    
}
