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
    private weak var interactionDelegate: LCPInteractionDelegate?

    init(licenses: LicensesRepository, crl: CRLService, device: DeviceService, network: NetworkService, passphrases: PassphrasesService, interactionDelegate: LCPInteractionDelegate?) {
        self.licenses = licenses
        self.crl = crl
        self.device = device
        self.network = network
        self.passphrases = passphrases
        self.interactionDelegate = interactionDelegate
    }

    fileprivate func retrieveLicense(from container: LicenseContainer, authentication: LCPAuthenticating?) -> Deferred<License> {
        return Deferred {
            let initialData = try container.read()
            
            func onValidateIntegrity(of license: LicenseDocument) throws {
                // FIXME: Should we do something with the errors here?
                
                try? self.licenses.addOrUpdateLicense(license)
                
                // Updates the License in the container if needed
                if license.data != initialData {
                    do {
                        try container.write(license)
                        LicensesService.log(.debug, "Wrote updated License Document in container")
                    } catch {
                        LicensesService.log(.error, "Failed to write updated License Document in container: \(error)")
                    }
                }
            }
            
            let validation = LicenseValidation(authentication: authentication, crl: self.crl, device: self.device, network: self.network, passphrases: self.passphrases, onValidateIntegrity: onValidateIntegrity)

            return validation.validate(.license(initialData))
                .map { documents in
                    // Check the license status error if there's any
                    // Note: Right now we don't want to return a License if it fails the Status check, that's why we attempt to get the DRM context. But it could change if we want to access, for example, the License metadata or perform an LSD interaction, but without being able to decrypt the book. In which case, we could remove this line.
                    // Note2: The License already gets in this state when we perform a `return` successfully. We can't decrypt anymore but we still have access to the License Documents and LSD interactions.
                    _ = try documents.getContext()
                    
                    return License(documents: documents, validation: validation, licenses: self.licenses, device: self.device, network: self.network, interactionDelegate: self.interactionDelegate)
                }
        }
    }

}

extension LicensesService: LCPService {
    
    func importPublication(from lcpl: URL, authentication: LCPAuthenticating?, completion: @escaping (LCPImportedPublication?, LCPError?) -> Void) {
        let container = LCPLLicenseContainer(lcpl: lcpl)
        retrieveLicense(from: container, authentication: authentication)
            .flatMap { $0.fetchPublication() }
            .map { LCPImportedPublication(localUrl: $0.0, downloadTask: $0.1) }
            .resolve(LCPError.wrap(completion))
    }
    
    func retrieveLicense(from publication: URL, authentication: LCPAuthenticating?, completion: @escaping (LCPLicense?, LCPError?) -> Void) {
        let container = EPUBLicenseContainer(epub: publication)
        retrieveLicense(from: container, authentication: authentication)
            .resolve(LCPError.wrap(completion))
    }
    
}
