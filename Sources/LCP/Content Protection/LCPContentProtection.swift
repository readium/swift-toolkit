//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

final class LCPContentProtection: ContentProtection, Loggable {
    private let service: LCPService
    private let authentication: LCPAuthenticating

    init(service: LCPService, authentication: LCPAuthenticating) {
        self.service = service
        self.authentication = authentication
    }

    func open(
        asset: Asset,
        credentials: String?,
        allowUserInteraction: Bool,
        sender: Any?
    ) async -> Result<ContentProtectionAsset, ContentProtectionOpenError> {
        guard asset.format.conformsTo(.lcp) else {
            return .failure(.assetNotSupported(DebugError("The asset does not appear to be protected with LCP")))
        }
        guard
            case var .container(asset) = asset,
            asset.container.sourceURL?.scheme == .file
        else {
            return .failure(.assetNotSupported(DebugError("Only container asset of local files are currently supported with LCP")))
        }

        return await parseEncryptionData(in: asset)
            .mapError { ContentProtectionOpenError.reading(.decoding($0)) }
            .asyncFlatMap { encryptionData in
                let authentication = credentials.map { LCPPassphraseAuthentication($0, fallback: self.authentication) }
                    ?? self.authentication

                let license = await self.service.retrieveLicense(
                    from: .container(asset),
                    authentication: authentication,
                    allowUserInteraction: allowUserInteraction,
                    sender: sender
                )

                if let license = try? license.get() {
                    let decryptor = LCPDecryptor(license: license, encryptionData: encryptionData)
                    asset.container = asset.container
                        .map(transform: decryptor.decrypt(at:resource:))
                }

                let cpAsset = ContentProtectionAsset(
                    asset: .container(asset),
                    onCreatePublication: { _, _, services in
                        services.setContentProtectionServiceFactory { _ in
                            LCPContentProtectionService(result: license)
                        }
                    }
                )

                return .success(cpAsset)
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

    convenience init(result: Result<LCPLicense?, LCPError>) {
        switch result {
        case let .success(license):
            self.init(license: license)
        case let .failure(error):
            self.init(error: error)
        }
    }

    let scheme: ContentProtectionScheme = .lcp

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
