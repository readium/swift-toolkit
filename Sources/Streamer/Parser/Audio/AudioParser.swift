//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Parses an audiobook Publication from an unstructured archive format containing audio files,
/// such as ZAB (Zipped Audio Book) or a simple ZIP.
///
/// It can also work for a standalone audio file.
public final class AudioParser: PublicationParser {
    private let assetRetriever: AssetRetriever
    private let manifestAugmentor: AudioPublicationManifestAugmentor

    public init(
        assetRetriever: AssetRetriever,
        manifestAugmentor: AudioPublicationManifestAugmentor = AVAudioPublicationManifestAugmentor()
    ) {
        self.assetRetriever = assetRetriever
        self.manifestAugmentor = manifestAugmentor
    }

    private let audioSpecifications: Set<FormatSpecification> = [
        .aac,
        .aiff,
        .flac,
        .mp4,
        .mp3,
        .ogg,
        .opus,
        .wav,
        .webm,
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
        guard asset.format.conformsToAny(audioSpecifications) else {
            return .failure(.formatNotSupported)
        }

        let container = SingleResourceContainer(publication: asset)
        return await makeBuilder(
            container: container,
            readingOrder: [(container.entry, asset.format)],
            title: nil
        )
    }

    private func parse(
        container asset: ContainerAsset,
        warnings: WarningLogger?
    ) async -> Result<Publication.Builder, PublicationParseError> {
        guard asset.format.conformsTo(.informalAudiobook) else {
            return .failure(.formatNotSupported)
        }

        return await makeReadingOrder(for: asset.container)
            .asyncFlatMap { readingOrder in
                await makeBuilder(
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
                            format.conformsToAny(audioSpecifications)
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
        let ignoredExtensions: [FileExtension] = [
            "asx",
            "bio",
            "m3u",
            "m3u8",
            "pla",
            "pls",
            "smil",
            "txt",
            "vlc",
            "wpl",
            "xspf",
            "zpl",
        ]

        return url.pathExtension == nil
            || ignoredExtensions.contains(url.pathExtension!)
            || filename.hasPrefix(".")
            || filename == "Thumbs.db"
    }

    private func makeBuilder(
        container: Container,
        readingOrder: [(AnyURL, Format)],
        title: String?
    ) async -> Result<Publication.Builder, PublicationParseError> {
        guard !readingOrder.isEmpty else {
            return .failure(.reading(.decoding("No audio resources found in the publication")))
        }

        let manifest = Manifest(
            metadata: Metadata(
                conformsTo: [.audiobook],
                title: title
            ),
            readingOrder: readingOrder.map { url, format in
                Link(
                    href: url.string,
                    mediaType: format.mediaType
                )
            }
        )

        let augmented = await manifestAugmentor.augment(manifest, using: container)

        return .success(Publication.Builder(
            manifest: augmented.manifest,
            container: container,
            servicesBuilder: .init(
                cover: augmented.cover.map(GeneratedCoverService.makeFactory(cover:)),
                locator: AudioLocatorService.makeFactory()
            )
        ))
    }
}
