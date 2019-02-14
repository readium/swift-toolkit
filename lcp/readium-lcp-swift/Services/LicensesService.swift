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

final class LicensesService {
    
    typealias LicenseFactory = (LicenseContainer, LCPAuthenticating?) -> License

    private let makeLicense: LicenseFactory

    init(makeLicense: @escaping LicenseFactory) {
        self.makeLicense = makeLicense
    }

    fileprivate func retrieveLicense(from container: LicenseContainer, authentication: LCPAuthenticating?) -> Deferred<License> {
        return makeLicense(container, authentication).evaluate()
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
