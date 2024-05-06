//
//  Copyright 2024 Readium Foundation. All rights reserved.
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
    public init() {}

    public func parse(asset: PublicationAsset, fetcher: Fetcher, warnings: WarningLogger?) throws -> Publication.Builder? {
        guard accepts(asset, fetcher) else {
            return nil
        }

        var readingOrder = fetcher.links
            .filter { !ignores($0) && $0.mediaType.isBitmap }
            .sorted { $0.href.localizedCaseInsensitiveCompare($1.href) == .orderedAscending }

        guard !readingOrder.isEmpty else {
            return nil
        }

        // First valid resource is the cover.
        readingOrder[0].rels = [.cover]

        return Publication.Builder(
            mediaType: .cbz,
            manifest: Manifest(
                metadata: Metadata(
                    conformsTo: [.divina],
                    title: fetcher.guessTitle(ignoring: ignores)
                ),
                readingOrder: readingOrder
            ),
            fetcher: fetcher,
            servicesBuilder: .init(
                positions: PerResourcePositionsService.makeFactory(fallbackMediaType: "image/*")
            )
        )
    }

    private func accepts(_ asset: PublicationAsset, _ fetcher: Fetcher) -> Bool {
        if asset.mediaType() == .cbz {
            return true
        }

        // Checks if the fetcher contains only bitmap-based resources.
        return !fetcher.links.isEmpty
            && fetcher.links.allSatisfy { ignores($0) || $0.mediaType.isBitmap }
    }

    private func ignores(_ link: Link) -> Bool {
        let url = URL(fileURLWithPath: link.href)
        let filename = url.lastPathComponent
        let allowedExtensions = ["acbf", "txt", "xml"]

        return allowedExtensions.contains(url.pathExtension.lowercased())
            || filename.hasPrefix(".")
            || filename == "Thumbs.db"
    }
}
