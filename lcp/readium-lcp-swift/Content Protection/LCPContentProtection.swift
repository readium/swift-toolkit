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
        allowUserInteraction: Bool,
        credentials: String?,
        sender: Any?,
        completion: @escaping (CancellableResult<ProtectedFile?, Publication.OpeningError>) -> Void)
    {
        service.retrieveLicense(
            from: file.url,
            authentication: (allowUserInteraction || !authentication.requiresUserInteraction) ? authentication : nil,
            sender: sender
        ) { result in
            switch result {
            case .success(let license):
                guard let license = license else {
                    // Not protected with LCP.
                    completion(.success(nil))
                    return
                }
                completion(.success(self.makeProtectedFile(file: file, fetcher: fetcher, license: license)))
                
            case .failure(let error):
                completion(.failure(.wrap(error)))
                
            case .cancelled:
                completion(.success(self.makeProtectedFile(file: file, fetcher: fetcher, license: nil)))
            }
        }
    }
    
    /// If the `license` is nil, we open the `Publication` in a restricted state.
    private func makeProtectedFile(file: File, fetcher: Fetcher, license: LCPLicense?) -> ProtectedFile {
        return ProtectedFile(
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

public extension Publication {
    
    /// Indicates whether this `Publication` is protected by a Content Protection technology.
    var lcpLicense: LCPLicense? {
        findService(LCPContentProtectionService.self)?.license
    }
    
}
