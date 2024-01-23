//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

final class LCPContentProtection: ContentProtection, Loggable {
    private let service: LCPService
    private let authentication: LCPAuthenticating

    init(service: LCPService, authentication: LCPAuthenticating) {
        self.service = service
        self.authentication = authentication
    }

    func open(
        asset: PublicationAsset,
        fetcher: Fetcher,
        credentials: String?,
        allowUserInteraction: Bool,
        sender: Any?,
        completion: @escaping (CancellableResult<ProtectedAsset?, Publication.OpeningError>) -> Void
    ) {
        guard let file = asset as? FileAsset else {
            log(.warning, "Only `FileAsset` is supported with the `LCPContentProtection`. Make sure you are trying to open a package from the file system.")
            completion(.success(nil))
            return
        }

        let authentication = credentials.map { LCPPassphraseAuthentication($0, fallback: self.authentication) }
            ?? self.authentication

        service.retrieveLicense(
            from: file.url,
            authentication: authentication,
            allowUserInteraction: allowUserInteraction,
            sender: sender
        ) { result in
            if case let .success(license) = result, license == nil {
                // Not protected with LCP.
                completion(.success(nil))
                return
            }

            let license = try? result.get()
            let protectedAsset = ProtectedAsset(
                asset: asset,
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

            completion(.success(protectedAsset))
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
        case let .success(license):
            self.init(license: license)
        case let .failure(error):
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
