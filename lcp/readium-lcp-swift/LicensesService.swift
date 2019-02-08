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

public class LicensesService {

    private let supportedProfiles: [String]
    private let device = DeviceService(repository: LcpDatabase.shared.licenses)
    private let crl = CrlService()

    public init(supportedProfiles: [String]) {
        self.supportedProfiles = supportedProfiles
    }

    fileprivate func openLicense(from container: LicenseContainer, authenticating: LcpAuthenticating?) -> DeferredResult<License> {
        let supportedProfiles = self.supportedProfiles
        let passphrases = PassphrasesService(repository: LcpDatabase.shared.transactions, authenticating: authenticating)
        let device = self.device
        let crl = self.crl
        let makeValidation = { LicenseValidation(supportedProfiles: supportedProfiles, passphrases: passphrases, licenses: LcpDatabase.shared.licenses, device: device, crl: crl) }
        let license = License(container: container, makeValidation: makeValidation, device: device)
        return deferred { license.validate($0) }
    }

}

extension LicensesService: LcpService {
    
    public func importLicenseDocument(_ lcpl: URL, authenticating: LcpAuthenticating?, completion: @escaping (LcpImportedPublication?, LcpError?) -> Void) {
        let container = LcplLicenseContainer(lcpl: lcpl)
        openLicense(from: container, authenticating: authenticating)
            .map { license, completion in
                license.fetchPublication(completion)
            }
            .map { LcpImportedPublication(localUrl: $0.0, downloadTask: $0.1) }
            .resolve(completion)
    }
    
    public func openLicense(in publication: URL, authenticating: LcpAuthenticating?, completion: @escaping (LcpLicense?, LcpError?) -> Void) {
        let container = EpubLicenseContainer(epub: publication)
        openLicense(from: container, authenticating: authenticating)
            .resolve(completion)
    }
    
}
