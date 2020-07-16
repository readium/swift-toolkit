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
        onAskCredentials: OnAskCredentials?,
        completion: @escaping (Result<ProtectedFile?, Publication.OpeningError>) -> Void)
    {
        guard file.format?.mediaType.isLCPProtected == true else {
            completion(.success(nil))
            return
        }
        
        service.retrieveLicense(
            from: file.url,
            authentication: (allowUserInteraction || !authentication.requiresUserInteraction) ? authentication : nil,
            sender: sender
        ) { result in
            switch result {
            case .success(let license):
                let protectedFile = ProtectedFile(
                    file: file,
                    fetcher: TransformingFetcher(
                        fetcher: fetcher,
                        transformer: LCPDecryptor(license: license).decrypt(resource:)
                    ),
                    onCreatePublication: { _, _, _, services in
                        services.setContentProtectionServiceFactory { _ in
                            LCPContentProtectionService(license: license)
                        }
                    }
                )
                completion(.success(protectedFile))
                
            case .failure(let error):
                completion(.failure(.wrap(error)))
            }
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
    
    private let license: LCPLicense?
    
    init(license: LCPLicense?) {
        self.license = license
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
