//
//  LicensesService.swift
//  r2-lcp-swift
//
//  Created by Mickaël Menu on 01.02.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared


final class LicensesService: Loggable {
    
    private let licenses: LicensesRepository
    private let crl: CRLService
    private let device: DeviceService
    private let network: NetworkService
    private let passphrases: PassphrasesService

    init(licenses: LicensesRepository, crl: CRLService, device: DeviceService, network: NetworkService, passphrases: PassphrasesService) {
        self.licenses = licenses
        self.crl = crl
        self.device = device
        self.network = network
        self.passphrases = passphrases
    }

    fileprivate func retrieveLicense(from container: LicenseContainer, authentication: LCPAuthenticating?) -> Deferred<License> {
        return Deferred {
            let initialData = try container.read()
            
            func onLicenseValidated(of license: LicenseDocument) throws {
                // Any errors are ignored to avoid blocking the publication.
                
                do {
                    try self.licenses.addLicense(license)
                } catch {
                    self.log(.error, "Failed to add the LCP License to the local database: \(error)")
                }
                
                // Updates the License in the container if needed
                if license.data != initialData {
                    do {
                        try container.write(license)
                        self.log(.debug, "Wrote updated License Document in container")
                    } catch {
                        self.log(.error, "Failed to write updated License Document in container: \(error)")
                    }
                }
            }
            
            let validation = LicenseValidation(authentication: authentication, crl: self.crl, device: self.device, network: self.network, passphrases: self.passphrases, onLicenseValidated: onLicenseValidated)

            return validation.validate(.license(initialData))
                .map { documents in
                    // Check the license status error if there's any
                    // Note: Right now we don't want to return a License if it fails the Status check, that's why we attempt to get the DRM context. But it could change if we want to access, for example, the License metadata or perform an LSD interaction, but without being able to decrypt the book. In which case, we could remove this line.
                    // Note2: The License already gets in this state when we perform a `return` successfully. We can't decrypt anymore but we still have access to the License Documents and LSD interactions.
                    _ = try documents.getContext()
                    
                    return License(documents: documents, validation: validation, licenses: self.licenses, device: self.device, network: self.network)
                }
        }
    }

}

extension LicensesService: LCPService {
    
    func importPublication(from lcpl: URL, authentication: LCPAuthenticating?, completion: @escaping (LCPImportedPublication?, LCPError?) -> Void) -> Observable<DownloadProgress> {
        let progress = MutableObservable<DownloadProgress>(.infinite)
        let container = LCPLLicenseContainer(lcpl: lcpl)
        retrieveLicense(from: container, authentication: authentication)
            .asyncMap { license, completion in
                let downloadProgress = license.fetchPublication { result, error in
                    progress.value = .infinite
                    if let result = result {
                        let publication = LCPImportedPublication(localURL: result.0, downloadTask: result.1, suggestedFilename: "\(license.license.id).epub")
                        completion(publication, nil)
                    } else {
                        completion(nil, error)
                    }
                }
                // Forwards the download progress to the global import progress
                downloadProgress.observe(progress)
            }
            .resolve(LCPError.wrap(completion))
        
        return progress
    }
    
    func retrieveLicense(from publication: URL, authentication: LCPAuthenticating?, completion: @escaping (LCPLicense?, LCPError?) -> Void) {
        let container = EPUBLicenseContainer(epub: publication)
        retrieveLicense(from: container, authentication: authentication)
            .resolve(LCPError.wrap(completion))
    }
    
}
