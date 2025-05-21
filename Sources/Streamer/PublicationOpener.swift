//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Opens a ``Publication`` from an ``Asset``.
///
/// - Parameters:
///   - parser: Parses the content of a publication ``Asset``.
///   - contentProtections: Opens DRM-protected publications.
///   - onCreatePublication: Called on every parsed `Publication.Builder`. It
///   can be used to modify the manifest, the root container or the list of
///   service factories of a ``Publication``.
public class PublicationOpener {
    private let parser: PublicationParser
    private let contentProtections: [ContentProtection]
    private let onCreatePublication: Publication.Builder.Transform

    public init(
        parser: PublicationParser,
        contentProtections: [ContentProtection] = [],
        onCreatePublication: @escaping Publication.Builder.Transform = { _, _, _ in }
    ) {
        self.parser = parser
        self.contentProtections = contentProtections + [_FallbackContentProtection()]
        self.onCreatePublication = onCreatePublication
    }

    /// Opens a ``Publication`` from the given asset.
    ///
    /// If you are opening the publication to render it in a Navigator, you
    /// must set ``allowUserInteraction`` to true to prompt the user for its
    /// credentials when the publication is protected. However, set it to false
    /// if you just want to import the ``Publication`` without reading its
    /// content, to avoid prompting the user.
    ///
    /// The ``warnings`` logger can be used to observe non-fatal parsing
    /// warnings, caused by publication authoring mistakes. This can be useful
    /// to warn users of potential rendering issues.
    ///
    /// - Parameters:
    ///   - asset: Asset providing access to the publication content.
    ///   - allowUserInteraction: Indicates whether the user can be prompted,
    ///     for example for its credentials.
    ///   - credentials: Credentials that content protections can use to
    ///     attempt to unlock a publication, for example a password.
    ///   - onCreatePublication: Transformation which will be applied on the
    ///     Publication Builder. It can be used to modify the manifest, the root
    ///     container or the list of service factories of the ``Publication``.
    ///   - warnings: Logger used to broadcast non-fatal parsing warnings.
    ///   - sender: Free object that can be used by reading apps to give some
    ///     UX context when presenting dialogs.
    public func open(
        asset: Asset,
        allowUserInteraction: Bool,
        credentials: String? = nil,
        onCreatePublication: @escaping Publication.Builder.Transform = { _, _, _ in },
        warnings: WarningLogger? = nil,
        sender: Any? = nil
    ) async -> Result<Publication, PublicationOpenError> {
        var asset = asset
        var builderTransforms: [Publication.Builder.Transform] = [
            self.onCreatePublication,
            onCreatePublication,
        ]

        for protection in contentProtections {
            switch await protection.open(
                asset: asset,
                credentials: credentials,
                allowUserInteraction: allowUserInteraction,
                sender: sender
            ) {
            case let .success(contentProtectionAsset):
                asset = contentProtectionAsset.asset
                if let transform = contentProtectionAsset.onCreatePublication {
                    builderTransforms.insert(transform, at: 0)
                }
            case let .failure(error):
                switch error {
                case .assetNotSupported:
                    break
                case let .reading(error):
                    return .failure(.reading(error))
                }
            }
        }

        switch await parser.parse(asset: asset, warnings: warnings) {
        case var .success(builder):
            for transform in builderTransforms {
                builder.apply(transform)
            }
            return .success(builder.build())

        case let .failure(error):
            switch error {
            case .formatNotSupported:
                return .failure(.formatNotSupported)
            case let .reading(error):
                return .failure(.reading(error))
            }
        }
    }
}

public enum PublicationOpenError: Error {
    /// The asset is not supported by the publication parser.
    case formatNotSupported

    /// An error occurred while trying to read the asset.
    case reading(ReadError)
}
