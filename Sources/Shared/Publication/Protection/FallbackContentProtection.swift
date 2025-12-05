//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// ``ContentProtection`` implementation used as a fallback when detecting
/// known DRMs not supported by the app.
public final class _FallbackContentProtection: ContentProtection {
    public init() {}

    public func open(
        asset: Asset,
        credentials: String?,
        allowUserInteraction: Bool,
        sender: Any?
    ) async -> Result<ContentProtectionAsset, ContentProtectionOpenError> {
        guard case .container = asset else {
            return .failure(.assetNotSupported(nil))
        }

        let scheme: ContentProtectionScheme
        if asset.format.conformsTo(.lcp) {
            scheme = .lcp
        } else if asset.format.conformsTo(.adept) {
            scheme = .adept
        } else {
            return .failure(.assetNotSupported(nil))
        }

        return .success(ContentProtectionAsset(
            asset: asset,
            onCreatePublication: { _, _, services in
                services.setContentProtectionServiceFactory { _ in
                    Service(scheme: scheme)
                }
            }
        ))
    }

    private final class Service: ContentProtectionService {
        let scheme: ContentProtectionScheme
        let isRestricted: Bool = true
        let error: Error?

        init(scheme: ContentProtectionScheme) {
            self.scheme = scheme
            error = ContentProtectionSchemeNotSupportedError(scheme: scheme)
        }

        let rights: UserRights = AllRestrictedUserRights()
    }
}
