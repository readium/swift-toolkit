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

    // Mapping between an unprotected format to the matching LCP protected format.
    private let mediaTypesMapping: [MediaType: MediaType] = [
        .readiumAudiobook: .lcpProtectedAudiobook,
        .pdf: .lcpProtectedPDF
    ]

    private let isProduction: Bool
    private let client: LCPClient
    private let licenses: LicensesRepository
    private let crl: CRLService
    private let device: DeviceService
    private let httpClient: HTTPClient
    private let passphrases: PassphrasesService

    init(isProduction: Bool, client: LCPClient, licenses: LicensesRepository, crl: CRLService, device: DeviceService, httpClient: HTTPClient, passphrases: PassphrasesService) {
        self.isProduction = isProduction
        self.client = client
        self.licenses = licenses
        self.crl = crl
        self.device = device
        self.httpClient = httpClient
        self.passphrases = passphrases
    }

    func retrieve(from publication: URL, authentication: LCPAuthenticating?, allowUserInteraction: Bool, sender: Any?) -> Deferred<License?, LCPError> {
        return makeLicenseContainer(for: publication)
            .flatMap { container in
                guard let container = container, container.containsLicense() else {
                    // Not protected with LCP
                    return .success(nil)
                }

                return self.retrieve(from: container, authentication: authentication, allowUserInteraction: allowUserInteraction, sender: sender)
                    .map { $0 as License? }
                    .mapError(LCPError.wrap)
            }
    }

    fileprivate func retrieve(from container: LicenseContainer, authentication: LCPAuthenticating?, allowUserInteraction: Bool, sender: Any?) -> Deferred<License, Error> {
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
            
            let validation = LicenseValidation(
                authentication: authentication,
                allowUserInteraction: allowUserInteraction,
                sender: sender,
                isProduction: self.isProduction,
                client: self.client,
                crl: self.crl,
                device: self.device,
                httpClient: self.httpClient,
                passphrases: self.passphrases,
                onLicenseValidated: onLicenseValidated
            )

            return validation.validate(.license(initialData))
                .tryMap { documents in
                    // Check the license status error if there's any
                    // Note: Right now we don't want to return a License if it fails the Status check, that's why we attempt to get the DRM context. But it could change if we want to access, for example, the License metadata or perform an LSD interaction, but without being able to decrypt the book. In which case, we could remove this line.
                    // Note2: The License already gets in this state when we perform a `return` successfully. We can't decrypt anymore but we still have access to the License Documents and LSD interactions.
                    _ = try documents.getContext()

                    return License(documents: documents, client: self.client, validation: validation, licenses: self.licenses, device: self.device, httpClient: self.httpClient)
                }
        }
    }
    
    func acquirePublication(from lcpl: URL, onProgress: @escaping (LCPAcquisition.Progress) -> Void, completion: @escaping (CancellableResult<LCPAcquisition.Publication, LCPError>) -> Void) -> LCPAcquisition {
        let acquisition = LCPAcquisition(onProgress: onProgress, completion: completion)
        
        readLicense(from: lcpl).resolve { result in
            switch result {
            case .success(let license):
                guard let license = license else {
                    acquisition.cancel()
                    return
                }

                self.acquirePublication(from: license, using: acquisition)

            case .failure(let error):
                acquisition.didComplete(with: .failure(error))
            case .cancelled:
                acquisition.cancel()
            }
        }

        return acquisition
    }
    
    private func readLicense(from lcpl: URL) -> Deferred<LicenseDocument?, LCPError> {
        makeLicenseContainer(for: lcpl)
            .tryMap { container in
                guard let container = container, container.containsLicense() else {
                    // Not protected with LCP
                    return nil
                }
                
                return try LicenseDocument(data: container.read())
            }
            .mapError(LCPError.wrap)
    }

    private func acquirePublication(from license: LicenseDocument, using acquisition: LCPAcquisition) {
        guard !acquisition.cancellable.isCancelled else {
            return
        }

        do {
            let url = try license.url(for: .publication)
            let cancellable = httpClient.download(
                url,
                onProgress: { acquisition.onProgress(.percent(Float($0))) },
                completion: { result in
                    switch result {
                    case .success(let download):
                        self.injectLicense(license, in: download)
                            .resolve { result in
                                switch result {
                                case .success(let file):
                                    acquisition.didComplete(with: .success(LCPAcquisition.Publication(
                                        localURL: file,
                                        suggestedFilename: self.suggestedFilename(for: file, license: license)
                                    )))
                                case .failure(let error):
                                    acquisition.didComplete(with: .failure(LCPError.wrap(error)))
                                case .cancelled:
                                    acquisition.cancel()
                                }
                            }

                    case .failure(let error):
                        acquisition.didComplete(with: .failure(LCPError.wrap(error)))
                    }
                }
            )
            acquisition.cancellable.mediate(cancellable)

        } catch {
            acquisition.didComplete(with: .failure(.wrap(error)))
        }
    }
    
    /// Injects the given License Document into the `file` acquired using `downloadTask`.
    private func injectLicense(_ license: LicenseDocument, in download: HTTPDownload) -> Deferred<URL, LCPError> {
        var mimetypes: [String] = [
            download.mediaType.string
        ]
        if let linkType = license.link(for: .publication)?.type {
            mimetypes.append(linkType)
        }

        return makeLicenseContainer(for: download.location, mimetypes: mimetypes)
            .tryMap(on: .global(qos: .background)) { container -> URL in
                guard let container = container else {
                    throw LCPError.licenseContainer(.openFailed)
                }

                try container.write(license)
                return download.location
            }
            .mapError(LCPError.wrap)
    }

    /// Returns the suggested filename to be used when importing a publication.
    private func suggestedFilename(for file: URL, license: LicenseDocument) -> String {
        let fileExtension: String = {
            let publicationLink = license.link(for: .publication)
            if var mediaType = MediaType.of(file, mediaType: publicationLink?.type) {
                mediaType = mediaTypesMapping[mediaType] ?? mediaType
                return mediaType.fileExtension ?? file.pathExtension
            } else {
                return file.pathExtension
            }
        }()

        return "\(license.id).\(fileExtension)"
    }

}
