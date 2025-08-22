//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Parses an image–based Publication from an unstructured archive format containing bitmap files,
/// such as CBZ or a simple ZIP.
///
/// It can also work for a standalone bitmap file.
public final class ImageParser: PublicationParser {
    private let assetRetriever: AssetRetriever

    public init(
        assetRetriever: AssetRetriever
    ) {
        self.assetRetriever = assetRetriever
    }

    private let bitmapSpecifications: Set<FormatSpecification> = [
        .avif,
        .bmp,
        .gif,
        .jpeg,
        .png,
        .tiff,
        .webp,
    ]

    public func parse(
        asset: Asset,
        warnings: WarningLogger?
    ) async -> Result<Publication.Builder, PublicationParseError> {
        switch asset {
        case let .resource(asset):
            return await parse(resource: asset, warnings: warnings)
        case let .container(asset):
            return await parse(container: asset, warnings: warnings)
        }
    }

    private func parse(
        resource asset: ResourceAsset,
        warnings: WarningLogger?
    ) async -> Result<Publication.Builder, PublicationParseError> {
        guard asset.format.conformsToAny(bitmapSpecifications) else {
            return .failure(.formatNotSupported)
        }

        let container = SingleResourceContainer(publication: asset)
        return makeBuilder(
            container: container,
            readingOrder: [(container.entry, asset.format)],
            title: nil
        )
    }

    private func parse(
        container asset: ContainerAsset,
        warnings: WarningLogger?
    ) async -> Result<Publication.Builder, PublicationParseError> {
        guard asset.format.conformsTo(.informalComic) else {
            return .failure(.formatNotSupported)
        }

        return await makeReadingOrder(for: asset.container)
            .flatMap { readingOrder in
                makeBuilder(
                    container: asset.container,
                    readingOrder: readingOrder,
                    title: asset.container.guessTitle(ignoring: ignores)
                )
            }
    }

    private func makeReadingOrder(for container: Container) async -> Result<[(AnyURL, Format)], PublicationParseError> {
        await container
            .sniffFormats(
                using: assetRetriever,
                ignoring: ignores
            )
            .map { formats in
                container.entries
                    .compactMap { url -> (AnyURL, Format)? in
                        guard
                            let format = formats[url],
                            format.conformsToAny(bitmapSpecifications)
                        else {
                            return nil
                        }
                        return (url, format)
                    }
                    .sorted { $0.0.string.localizedStandardCompare($1.0.string) == .orderedAscending }
            }
            .mapError { .reading($0) }
    }

    private func ignores(_ url: AnyURL) -> Bool {
        guard let filename = url.lastPathSegment else {
            return true
        }
        let ignoredExtensions: [FileExtension] = ["acbf", "txt", "xml"]

        return url.pathExtension == nil
            || ignoredExtensions.contains(url.pathExtension!)
            || filename.hasPrefix(".")
            || filename == "Thumbs.db"
    }

    private func makeBuilder(
        container: Container,
        readingOrder: [(AnyURL, Format)],
        title: String?
    ) -> Result<Publication.Builder, PublicationParseError> {
        guard !readingOrder.isEmpty else {
            return .failure(.reading(.decoding("No bitmap resources found in the publication")))
        }

        var readingOrder = readingOrder.map { url, format in
            Link(
                href: url.string,
                mediaType: format.mediaType
            )
        }

        // First valid resource is the cover.
        readingOrder[0].rels = [.cover]

        return .success(Publication.Builder(
            manifest: Manifest(
                metadata: Metadata(
                    conformsTo: [.divina],
                    title: title
                ),
                readingOrder: readingOrder
            ),
            container: container,
            servicesBuilder: .init(
                positions: PerResourcePositionsService.makeFactory(fallbackMediaType: MediaType("image/*")!)
            )
        ))
    }
}
