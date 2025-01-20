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
    private let assetRetriever: AssetRetriever

    init(service: LCPService, authentication: LCPAuthenticating, assetRetriever: AssetRetriever) {
        self.service = service
        self.authentication = authentication
        self.assetRetriever = assetRetriever
    }

    func open(
        asset: Asset,
        credentials: String?,
        allowUserInteraction: Bool,
        sender: Any?
    ) async -> Result<ContentProtectionAsset, ContentProtectionOpenError> {
        switch asset {
        case let .resource(resource):
            return await openLicense(
                using: resource,
                credentials: credentials,
                allowUserInteraction: allowUserInteraction,
                sender: sender
            )

        case let .container(container):
            return await openPublication(
                in: container,
                credentials: credentials,
                allowUserInteraction: allowUserInteraction,
                sender: sender
            )
        }
    }

    func openLicense(
        using asset: ResourceAsset,
        credentials: String?,
        allowUserInteraction: Bool,
        sender: Any?
    ) async -> Result<ContentProtectionAsset, ContentProtectionOpenError> {
        guard asset.format.conformsTo(.lcpLicense) else {
            return .failure(.assetNotSupported(DebugError("The asset does not appear to be an LCP License")))
        }

        return await asset.resource.readAsLCPL()
            .mapError { .reading($0) }
            .asyncFlatMap { licenseDocument in
                let link = licenseDocument.publicationLink
                guard let url = link.url() else {
                    return .failure(.reading(.decoding("The LCP License Document does not contain a valid HTTP URL to the protected publication")))
                }

                return await assetRetriever.retrieve(
                    url: url,
                    hints: FormatHints(mediaType: link.mediaType)
                )
                .mapError { error in
                    switch error {
                    case .formatNotSupported, .schemeNotSupported:
                        return .assetNotSupported(error)
                    case let .reading(error):
                        return .reading(error)
                    }
                }
                .flatMap { publicationAsset in
                    switch publicationAsset {
                    case .resource:
                        return .failure(.assetNotSupported(DebugError("Cannot open the LCP-protected publication as a Container")))
                    case let .container(container):
                        return .success(container)
                    }
                }
                .asyncFlatMap {
                    await makeLCPAsset(
                        from: $0,
                        license: retrieveLicense(
                            in: .resource(asset),
                            credentials: credentials,
                            allowUserInteraction: allowUserInteraction,
                            sender: sender
                        )
                    )
                }
            }
    }

    func openPublication(
        in asset: ContainerAsset,
        credentials: String?,
        allowUserInteraction: Bool,
        sender: Any?
    ) async -> Result<ContentProtectionAsset, ContentProtectionOpenError> {
        guard asset.format.conformsTo(.lcp) else {
            return .failure(.assetNotSupported(DebugError("The asset does not appear to be protected with LCP")))
        }

        // FIXME: Alternative to storing the license in the file?
//        guard asset.container.sourceURL?.scheme == .file else {
//            return .failure(.assetNotSupported(DebugError("Only container asset of local files are currently supported with LCP")))
//        }

        return await makeLCPAsset(
            from: asset,
            license: retrieveLicense(
                in: .container(asset),
                credentials: credentials,
                allowUserInteraction: allowUserInteraction,
                sender: sender
            )
        )
    }

    private func retrieveLicense(
        in asset: Asset,
        credentials: String?,
        allowUserInteraction: Bool,
        sender: Any?
    ) async -> Result<LCPLicense, LCPError> {
        let authentication = credentials.map { LCPPassphraseAuthentication($0, fallback: self.authentication) }
            ?? self.authentication

        return await service.retrieveLicense(
            from: asset,
            authentication: authentication,
            allowUserInteraction: allowUserInteraction,
            sender: sender
        )
    }

    func makeLCPAsset(
        from asset: ContainerAsset,
        license: Result<LCPLicense, LCPError>
    ) async -> Result<ContentProtectionAsset, ContentProtectionOpenError> {
        await parseEncryptionData(in: asset)
            .mapError { ContentProtectionOpenError.reading(.decoding($0)) }
            .asyncFlatMap { encryptionData in
                var asset = asset

                let decryptor = LCPDecryptor(license: license.getOrNil(), encryptionData: encryptionData)
                asset.container = asset.container
                    .map(transform: decryptor.decrypt(at:resource:))

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

    convenience init(result: Result<LCPLicense, LCPError>) {
        switch result {
        case let .success(license):
            self.init(license: license)

        case let .failure(error):
            switch error {
            case .missingPassphrase:
                // We don't expose errors due to user cancellation.
                self.init()

            default:
                self.init(error: error)
            }
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
