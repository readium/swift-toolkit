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

final class LicensesService {
    
    typealias LicenseFactory = (LicenseContainer, LCPAuthenticating?) -> License

    private let makeLicense: LicenseFactory

    init(makeLicense: @escaping LicenseFactory) {
        self.makeLicense = makeLicense
    }

    fileprivate func openLicense(from container: LicenseContainer, authenticating: LCPAuthenticating?) -> Deferred<License> {
        let license = makeLicense(container, authenticating)
        return license.open()
            // Forwards the created license, to apply more transformations on it.
            .map { license }
    }

}

extension LicensesService: LCPService {
    
    public func importLicenseDocument(_ lcpl: URL, authenticating: LCPAuthenticating?, completion: @escaping (LCPImportedPublication?, LCPError?) -> Void) {
        let container = LCPLLicenseContainer(lcpl: lcpl)
        openLicense(from: container, authenticating: authenticating)
            .flatMap { $0.fetchPublication() }
            .map { LCPImportedPublication(localUrl: $0.0, downloadTask: $0.1) }
            .resolve(LCPError.wrap(completion))
    }
    
    public func openLicense(in publication: URL, authenticating: LCPAuthenticating?, completion: @escaping (LCPLicense?, LCPError?) -> Void) {
        let container = EPUBLicenseContainer(epub: publication)
        openLicense(from: container, authenticating: authenticating)
            .resolve(LCPError.wrap(completion))
    }
    
}
