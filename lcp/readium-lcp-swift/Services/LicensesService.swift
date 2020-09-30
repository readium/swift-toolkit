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
    
    // Mapping between an unprotected format to the matching LCP protected format.
    private let formatsMapping: [Format: Format] = [
        .readiumAudiobook: .lcpProtectedAudiobook,
        .pdf: .lcpProtectedPDF
    ]

    init(licenses: LicensesRepository, crl: CRLService, device: DeviceService, network: NetworkService, passphrases: PassphrasesService) {
        self.licenses = licenses
        self.crl = crl
        self.device = device
        self.network = network
        self.passphrases = passphrases
    }
    
    func retrieveLicense(from publication: URL, authentication: LCPAuthenticating?, allowUserInteraction: Bool, sender: Any?) -> Deferred<LCPLicense?, LCPError> {
        return makeLicenseContainer(for: publication)
            .flatMap { container in
                guard let container = container, container.containsLicense() else {
                    // Not protected with LCP
                    return .success(nil)
                }

                return self.retrieveLicense(from: container, authentication: authentication, allowUserInteraction: allowUserInteraction, sender: sender)
                    .map { $0 as LCPLicense }
                    .mapError(LCPError.wrap)
            }
    }

    fileprivate func retrieveLicense(from container: LicenseContainer, authentication: LCPAuthenticating?, allowUserInteraction: Bool, sender: Any?) -> Deferred<License, Error> {
        return deferredCatching(on: .global(qos: .background)) {
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
            
            let validation = LicenseValidation(authentication: authentication, allowUserInteraction: allowUserInteraction, sender: sender, crl: self.crl, device: self.device, network: self.network, passphrases: self.passphrases, onLicenseValidated: onLicenseValidated)

            return validation.validate(.license(initialData))
                .tryMap { documents in
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

    func importPublication(from lcpl: URL, authentication: LCPAuthenticating?, sender: Any?, completion: @escaping (CancellableResult<LCPImportedPublication, LCPError>) -> Void) -> Observable<DownloadProgress> {
        let progress = MutableObservable<DownloadProgress>(.infinite)
        let container = LCPLLicenseContainer(lcpl: lcpl)
        retrieveLicense(from: container, authentication: authentication, allowUserInteraction: true, sender: sender)
            .asyncMap { (license, completion: (@escaping (CancellableResult<LCPImportedPublication, Error>) -> Void)) in
                let downloadProgress = license.fetchPublication { result in
                    progress.value = .infinite
                    switch result {
                    case .success(let res):
                        let filename = self.suggestedFilename(for: res.0, license: license)
                        let publication = LCPImportedPublication(localURL: res.0, downloadTask: res.1, suggestedFilename: filename)
                        completion(.success(publication))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
                // Forwards the download progress to the global import progress
                downloadProgress.observe(progress)
            }
            .mapError(LCPError.wrap)
            .resolve(completion)
        
        return progress
    }
    
    func retrieveLicense(from publication: URL, authentication: LCPAuthenticating?, allowUserInteraction: Bool, sender: Any?, completion: @escaping (CancellableResult<LCPLicense?, LCPError>) -> Void) {
        retrieveLicense(from: publication, authentication: authentication, allowUserInteraction: allowUserInteraction, sender: sender)
            .resolve(completion)
    }
    
    func contentProtection(with authentication: LCPAuthenticating) -> ContentProtection {
        return LCPContentProtection(service: self, authentication: authentication)
    }
    
    /// Returns the suggested filename to be used when importing a publication.
    private func suggestedFilename(for file: URL, license: License) -> String {
        let fileExtension: String = {
            let publicationLink = license.license.link(for: .publication)
            if var format = Format.of(file, mediaType: publicationLink?.type) {
                format = formatsMapping[format] ?? format
                return format.fileExtension
            } else {
                return file.pathExtension
            }
        }()
        
        return "\(license.license.id).\(fileExtension)"
    }

}
