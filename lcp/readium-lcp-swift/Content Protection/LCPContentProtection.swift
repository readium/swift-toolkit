//
//  LCPContentProtection.swift
//  r2-lcp-swift
//
//  Created by Mickaël Menu on 16/07/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared

final class LCPContentProtection: ContentProtection {
    
    private let service: LCPService
    private let authentication: LCPAuthenticating
    
    init(service: LCPService, authentication: LCPAuthenticating) {
        self.service = service
        self.authentication = authentication
    }
    
    func open(
        file: File,
        fetcher: Fetcher,
        credentials: String?,
        allowUserInteraction: Bool,
        sender: Any?,
        completion: @escaping (CancellableResult<ProtectedFile?, Publication.OpeningError>) -> Void)
    {
        service.retrieveLicense(
            from: file.url,
            authentication: authentication,
            allowUserInteraction: allowUserInteraction,
            sender: sender
        ) { result in
            if case .success(let license) = result, license == nil {
                // Not protected with LCP.
                completion(.success(nil))
                return
            }
            
            let license = try? result.get()
            let protectedFile = ProtectedFile(
                file: file,
                fetcher: TransformingFetcher(
                    fetcher: fetcher,
                    transformer: LCPDecryptor(license: license).decrypt(resource:)
                ),
                onCreatePublication: { _, _, _, services in
                    services.setContentProtectionServiceFactory { _ in
                        LCPContentProtectionService(result: result)
                    }
                }
            )
            
            completion(.success(protectedFile))
        }
    }

}

private extension Publication.OpeningError {
    
    static func wrap(_ error: LCPError) -> Publication.OpeningError {
        switch error {
        case .licenseIsBusy, .network, .licenseContainer:
            return .unavailable(error)
        case .licenseStatus:
            return .forbidden(error)
        default:
            return .parsingFailed(error)
        }
    }
    
}

private final class LCPContentProtectionService: ContentProtectionService {
    
    let license: LCPLicense?
    let error: Error?

    init(license: LCPLicense? = nil, error: Error? = nil) {
        self.license = license
        self.error = error
    }
    
    convenience init(result: CancellableResult<LCPLicense?, LCPError>) {
        switch result {
        case .success(let license):
            self.init(license: license)
        case .failure(let error):
            self.init(error: error)
        case .cancelled:
            self.init()
        }
    }
    
    var isRestricted: Bool {
        license == nil
    }
    
    var rights: UserRights {
        license ?? AllRestrictedUserRights()
    }
    
    var name: LocalizedString? {
        LocalizedString.nonlocalized("Readium LCP")
    }

}

public extension Publication {
    
    /// Returns the `LCPLicense` if the `Protection` is protected by LCP and the license is opened.
    var lcpLicense: LCPLicense? {
        findService(LCPContentProtectionService.self)?.license
    }
    
}
