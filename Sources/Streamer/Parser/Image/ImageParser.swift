//
//  Copyright 2026 Readium Foundation. All rights reserved.
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
        .jxl,
        .png,
        .tiff,
        .webp,
    ]

    public func parse(
        asset: Asset,
        warnings: WarningLogger?
    ) async throws(PublicationParseError) -> Publication.Builder {
        switch asset {
        case let .resource(asset):
            return try await parse(resource: asset, warnings: warnings)
        case let .container(asset):
            return try await parse(container: asset, warnings: warnings)
        }
    }

    private func parse(
        resource asset: ResourceAsset,
        warnings: WarningLogger?
    ) async throws(PublicationParseError) -> Publication.Builder {
        guard asset.format.conformsToAny(bitmapSpecifications) else {
            throw .formatNotSupported
        }

        let container = SingleResourceContainer(publication: asset)
        return try makeBuilder(
            container: container,
            readingOrder: [(container.entry, asset.format)]
        )
    }

    private func parse(
        container asset: ContainerAsset,
        warnings: WarningLogger?
    ) async throws(PublicationParseError) -> Publication.Builder {
        guard asset.format.conformsTo(.informalComic) else {
            throw .formatNotSupported
        }

        // Parse ComicInfo.xml metadata if present
        let comicInfo = await parseComicInfo(from: asset.container, warnings: warnings)

        let readingOrder = try await makeReadingOrder(for: asset.container)
        return try makeBuilder(
            container: asset.container,
            readingOrder: readingOrder,
            comicInfo: comicInfo
        )
    }

    /// Finds and parses the ComicInfo.xml file from the container.
    private func parseComicInfo(from container: Container, warnings: WarningLogger?) async -> ComicInfo? {
        // Look for ComicInfo.xml at the root or in a subdirectory
        guard
            let url = container.entries.first(where: { $0.lastPathSegment?.lowercased() == "comicinfo.xml" }),
            let data = try? await container.readData(at: url)
        else {
            return nil
        }

        return ComicInfoParser.parse(data: data, warnings: warnings)
    }

    private func makeReadingOrder(for container: Container) async throws(PublicationParseError) -> [(AnyURL, Format)] {
        let formats: [AnyURL: Format]
        do {
            formats = try await container
                .sniffFormats(
                    using: assetRetriever,
                    ignoring: ignores
                )
                .get()
        } catch {
            throw .reading(error)
        }

        return container.entries
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
        comicInfo: ComicInfo? = nil
    ) throws(PublicationParseError) -> Publication.Builder {
        guard !readingOrder.isEmpty else {
            throw .reading(.decoding("No bitmap resources found in the publication"))
        }

        var readingOrder = readingOrder.map { url, format in
            Link(
                href: url.string,
                mediaType: format.mediaType
            )
        }

        // Set cover if explicitly declared in ComicInfo.xml
        var coverIndex: Int?
        if
            let coverPage = comicInfo?.firstPageWithType(.frontCover),
            coverPage.image >= 0,
            coverPage.image < readingOrder.count
        {
            coverIndex = coverPage.image
            readingOrder[coverPage.image].rels.append(.cover)
        }

        // Determine story start index (where actual content begins)
        // Only set if different from cover page (prefer .cover if same page)
        if
            let storyPage = comicInfo?.firstPageWithType(.story),
            storyPage.image >= 0,
            storyPage.image < readingOrder.count,
            storyPage.image != coverIndex
        {
            readingOrder[storyPage.image].rels.append(.start)
        }

        // Build metadata from ComicInfo or use defaults
        var metadata = comicInfo?.toMetadata() ?? Metadata()
        metadata.conformsTo = [.divina]
        metadata.layout = .fixed

        // Apply center page layout for double-page spreads
        if let pages = comicInfo?.pages {
            for pageInfo in pages where pageInfo.doublePage == true {
                if readingOrder.indices.contains(pageInfo.image) {
                    readingOrder[pageInfo.image].properties.page = .center
                }
            }
        }

        return Publication.Builder(
            manifest: Manifest(
                metadata: metadata,
                readingOrder: readingOrder
            ),
            container: container,
            servicesBuilder: .init(
                positions: PerResourcePositionsService.makeFactory(fallbackMediaType: MediaType("image/*")!)
            )
        )
    }
}
