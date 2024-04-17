//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import AVFoundation
import Foundation
import R2Shared

/// Parses an audiobook Publication from an unstructured archive format containing audio files,
/// such as ZAB (Zipped Audio Book) or a simple ZIP.
///
/// It can also work for a standalone audio file.
public final class AudioParser: PublicationParser {
    public init() {}

    private func metadataItems(_ metadataItems: [AVMetadataItem], _ key: AVMetadataKey) -> [AVMetadataItem] {
        AVMetadataItem.metadataItems(from: metadataItems, withKey: key, keySpace: .common)
    }

    public func parse(asset: PublicationAsset, fetcher: Fetcher, warnings: WarningLogger?) throws -> Publication.Builder? {
        guard accepts(asset, fetcher) else {
            return nil
        }

        var readingOrder = fetcher.links
            .filter { !ignores($0) && $0.mediaType.isAudio }
            .sorted { $0.href.localizedCaseInsensitiveCompare($1.href) == .orderedAscending }

        guard !readingOrder.isEmpty else {
            return nil
        }

        let avAssets = readingOrder.map { link in fetcher.get(link).file.map { AVURLAsset(url: $0, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true]) } }

        readingOrder = zip(readingOrder, avAssets).map { link, avAsset in
            guard let avAsset else { return link }
            return link.copy(
                title: metadataItems(avAsset.metadata, .commonKeyTitle).first?.stringValue,
                bitrate: avAsset.tracks(withMediaType: .audio).first.map { Double($0.estimatedDataRate) },
                duration: avAsset.duration.seconds
            )
        }

        let durations = readingOrder.compactMap(\.duration)

        var metadata = Metadata(
            conformsTo: [.audiobook],
            title: fetcher.guessTitle(ignoring: ignores) ?? asset.name,
            duration: readingOrder.count == durations.count ? durations.reduce(0, +) : nil
        )

        if let avMetadata = avAssets.compactMap({ $0 }).first?.metadata {
            metadata = metadata.copy(
                title: metadataItems(avMetadata, .commonKeyTitle).first?.stringValue ?? metadata.title,
                modified: metadataItems(avMetadata, .commonKeyLastModifiedDate).first?.stringValue?.dateFromISO8601,
                published: metadataItems(avMetadata, .commonKeyCreationDate).first?.stringValue?.dateFromISO8601,
                languages: metadataItems(avMetadata, .commonKeyLanguage).compactMap(\.stringValue),
                subjects: metadataItems(avMetadata, .commonKeySubject).compactMap(\.stringValue).map { Subject(name: $0) },
                authors: metadataItems(avMetadata, .commonKeyAuthor).compactMap(\.stringValue).map { Contributor(name: $0) },
                contributors: metadataItems(avMetadata, .commonKeyContributor).compactMap(\.stringValue).map { Contributor(name: $0) },
                publishers: metadataItems(avMetadata, .commonKeyPublisher).compactMap(\.stringValue).map { Contributor(name: $0) },
                description: metadataItems(avMetadata, .commonKeyDescription).first?.stringValue
            )
        }

        return Publication.Builder(
            mediaType: .zab,
            format: .cbz,
            manifest: Manifest(
                metadata: metadata,
                readingOrder: readingOrder
            ),
            fetcher: fetcher,
            servicesBuilder: .init(
                locator: AudioLocatorService.makeFactory()
            )
        )
    }

    private func accepts(_ asset: PublicationAsset, _ fetcher: Fetcher) -> Bool {
        if asset.mediaType() == .zab {
            return true
        }

        // Checks if the fetcher contains only bitmap-based resources.
        return !fetcher.links.isEmpty
            && fetcher.links.allSatisfy { ignores($0) || $0.mediaType.isAudio }
    }

    private func ignores(_ link: Link) -> Bool {
        let url = URL(fileURLWithPath: link.href)
        let filename = url.lastPathComponent
        let allowedExtensions = ["asx", "bio", "m3u", "m3u8", "pla", "pls", "smil", "txt", "vlc", "wpl", "xspf", "zpl"]

        return allowedExtensions.contains(url.pathExtension.lowercased())
            || filename.hasPrefix(".")
            || filename == "Thumbs.db"
    }

    @available(*, unavailable, message: "Not supported for `AudioParser`")
    public static func parse(at url: URL) throws -> (PubBox, PubParsingCallback) {
        fatalError("Not supported for `AudioParser`")
    }
}
