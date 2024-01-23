//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

/// Opens a `Publication` using a list of parsers.
public final class Streamer: Loggable {
    /// Creates the default parsers provided by Readium.
    public static func makeDefaultParsers(
        pdfFactory: PDFDocumentFactory = DefaultPDFDocumentFactory(),
        httpClient: HTTPClient = DefaultHTTPClient()
    ) -> [PublicationParser] {
        [
            EPUBParser(),
            PDFParser(pdfFactory: pdfFactory),
            ReadiumWebPubParser(pdfFactory: pdfFactory, httpClient: httpClient),
            ImageParser(),
            AudioParser(),
        ]
    }

    /// `Streamer` is configured to use Readium's default parsers, which you can bypass using
    /// `ignoreDefaultParsers`. However, you can provide additional `parsers` which will take
    /// precedence over the default ones. This can also be used to provide an alternative
    /// configuration of a default parser.
    ///
    /// - Parameters:
    ///   - parsers: Parsers used to open a publication, in addition to the default parsers.
    ///   - ignoreDefaultParsers: When true, only parsers provided in parsers will be used.
    ///   - contentProtections: List of `ContentProtection` used to unlock publications. Each
    ///     `ContentProtection` is tested in the given order.
    ///   - archiveFactory: Opens an archive (e.g. ZIP, RAR), optionally protected by credentials.
    ///   - pdfFactory: Parses a PDF document, optionally protected by password.
    ///   - httpClient: Service performing HTTP requests.
    ///   - onCreatePublication: Transformation which will be applied on every parsed Publication
    ///     Builder. It can be used to modify the `Manifest`, the root `Fetcher` or the list of
    ///     service factories of a `Publication`.
    public init(
        parsers: [PublicationParser] = [],
        ignoreDefaultParsers: Bool = false,
        contentProtections: [ContentProtection] = [],
        archiveFactory: ArchiveFactory = DefaultArchiveFactory(),
        pdfFactory: PDFDocumentFactory = DefaultPDFDocumentFactory(),
        httpClient: HTTPClient = DefaultHTTPClient(),
        onCreatePublication: Publication.Builder.Transform? = nil
    ) {
        self.parsers = parsers + (ignoreDefaultParsers ? [] : Streamer.makeDefaultParsers(pdfFactory: pdfFactory, httpClient: httpClient))
        self.contentProtections = contentProtections
        self.archiveFactory = archiveFactory
        self.onCreatePublication = onCreatePublication
    }

    private let parsers: [PublicationParser]
    private let contentProtections: [ContentProtection]
    private let archiveFactory: ArchiveFactory
    private let onCreatePublication: Publication.Builder.Transform?

    /// Parses a `Publication` from the given asset.
    ///
    /// If you are opening the publication to render it in a Navigator, you must set
    /// `allowUserInteraction`to true to prompt the user for its credentials when the publication is
    /// protected. However, set it to false if you just want to import the `Publication` without
    /// reading its content, to avoid prompting the user.
    ///
    /// When using Content Protections, you can use `sender` to provide a free object which can be
    /// used to give some context. For example, it could be the source `UIViewController` which
    /// would be used to present a credentials dialog.
    ///
    /// The `warnings` logger can be used to observe non-fatal parsing warnings, caused by
    /// publication authoring mistakes. This can be useful to warn users of potential rendering
    /// issues.
    ///
    /// - Parameters:
    ///   - asset: Digital medium (e.g. a file) used to access the publication.
    ///   - credentials: Credentials that Content Protections can use to attempt to unlock a
    ///     publication, for example a password.
    ///   - allowUserInteraction: Indicates whether the user can be prompted during opening, for
    ///     example to ask their credentials.
    ///   - sender: Free object that can be used by reading apps to give some UX context when
    ///     presenting dialogs.
    ///   - onCreatePublication: Transformation which will be applied on the Publication Builder.
    ///     It can be used to modify the `Manifest`, the root `Fetcher` or the list of service
    ///     factories of the `Publication`.
    ///   - warnings: Logger used to broadcast non-fatal parsing warnings.
    public func open(
        asset: PublicationAsset,
        credentials: String? = nil,
        allowUserInteraction: Bool,
        sender: Any? = nil,
        warnings: WarningLogger? = nil,
        onCreatePublication: Publication.Builder.Transform? = nil,
        completion: @escaping (CancellableResult<Publication, Publication.OpeningError>) -> Void
    ) {
        log(.info, "Open \(asset)")

        return makeFetcher(for: asset, allowUserInteraction: allowUserInteraction, credentials: credentials, sender: sender)
            .flatMap { fetcher in
                // Unlocks any protected asset with the Content Protections.
                self.unlockAsset(asset, with: fetcher, credentials: credentials, allowUserInteraction: allowUserInteraction, sender: sender)
            }
            .flatMap { asset in
                // Parses the Publication using the parsers.
                self.parsePublication(from: asset, warnings: warnings, onCreatePublication: onCreatePublication)
            }
            .resolve(on: .main, completion)
    }

    /// Creates the leaf fetcher which will be passed to the content protections and parsers.
    private func makeFetcher(for asset: PublicationAsset, allowUserInteraction: Bool, credentials: String?, sender: Any?) -> Deferred<Fetcher, Publication.OpeningError> {
        deferred { completion in
            asset.makeFetcher(using: .init(archiveFactory: self.archiveFactory), credentials: credentials, completion: completion)
        }
    }

    /// Unlocks any protected asset with the provided Content Protections.
    private func unlockAsset(_ asset: PublicationAsset, with fetcher: Fetcher, credentials: String?, allowUserInteraction: Bool, sender: Any?) -> Deferred<OpenedAsset, Publication.OpeningError> {
        func unlock(using protections: [ContentProtection]) -> Deferred<ProtectedAsset?, Publication.OpeningError> {
            deferred {
                var protections = protections
                guard let protection = protections.popFirst() else {
                    // No Content Protection applied, this asset is probably not protected.
                    return .success(nil)
                }

                return protection
                    .open(asset: asset, fetcher: fetcher, credentials: credentials, allowUserInteraction: allowUserInteraction, sender: sender)
                    .flatMap {
                        if let protectedAsset = $0 {
                            return .success(protectedAsset)
                        } else {
                            return unlock(using: protections)
                        }
                    }
            }
        }

        return unlock(using: contentProtections)
            .map { protectedAsset in
                protectedAsset ?? OpenedAsset(asset, fetcher, nil)
            }
    }

    /// Parses the `Publication` from the provided asset and the `parsers`.
    private func parsePublication(from openedAsset: OpenedAsset, warnings: WarningLogger?, onCreatePublication: Publication.Builder.Transform?) -> Deferred<Publication, Publication.OpeningError> {
        deferred(on: .global(qos: .userInitiated)) {
            var parsers = self.parsers
            var parsedBuilder: Publication.Builder?
            while parsedBuilder == nil, let parser = parsers.popFirst() {
                do {
                    parsedBuilder = try parser.parse(asset: openedAsset.asset, fetcher: openedAsset.fetcher, warnings: warnings)
                } catch {
                    return .failure(.parsingFailed(error))
                }
            }

            guard var builder = parsedBuilder else {
                return .failure(.unsupportedFormat)
            }

            // Transform from the Content Protection.
            builder.apply(openedAsset.onCreatePublication)
            // Transform provided by the reading app during the construction of the `Streamer`.
            builder.apply(self.onCreatePublication)
            // Transform provided by the reading app in `Streamer.open()`.
            if let onCreatePublication = onCreatePublication {
                builder.apply(onCreatePublication)
            }

            return .success(builder.build())
        }
    }

    @available(*, unavailable, message: "Provide a `FileAsset` instead", renamed: "open(asset:credentials:allowUserInteraction:sender:warnings:onCreatePublication:completion:)")
    public func open(file: File, credentials: String? = nil, allowUserInteraction: Bool, sender: Any? = nil, warnings: WarningLogger? = nil, onCreatePublication: Publication.Builder.Transform? = nil, completion: @escaping (CancellableResult<Publication, Publication.OpeningError>) -> Void) {}
}

private typealias OpenedAsset = (asset: PublicationAsset, fetcher: Fetcher, onCreatePublication: Publication.Builder.Transform?)

private extension ContentProtection {
    /// Wrapper to use `Deferred` with `ContentProtection.open()`.
    func open(asset: PublicationAsset, fetcher: Fetcher, credentials: String?, allowUserInteraction: Bool, sender: Any?) -> Deferred<ProtectedAsset?, Publication.OpeningError> {
        deferred { completion in
            self.open(asset: asset, fetcher: fetcher, credentials: credentials, allowUserInteraction: allowUserInteraction, sender: sender, completion: completion)
        }
    }
}
