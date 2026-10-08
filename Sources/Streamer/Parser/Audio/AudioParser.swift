//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Parses an audiobook Publication from an unstructured archive format
/// containing audio files, such as ZAB (Zipped Audio Book) or a simple ZIP.
///
/// It can also work for a standalone audio file.
///
/// The metadata, the table of contents and the cover of the publication come
/// from the tags of its audio files, which are read with an
/// ``AudioMetadataReader``.
public final class AudioParser: PublicationParser {
    private let assetRetriever: AssetRetriever
    private let metadataReader: AudioMetadataReader
    private let readsContainerEntriesMetadata: Bool

    /// Number of audio files read at the same time.
    private let metadataBatchSize = 4

    /// - Parameters:
    ///   - assetRetriever: Sniffs the format of the files of a package.
    ///   - metadataReader: Reads the metadata embedded in each audio file.
    ///     The default one only reads files of the file system, so the
    ///     entries of a ZIP archive have no metadata.
    ///   - readsContainerEntriesMetadata: When false, the audio files of a
    ///     package are not opened: the publication has no title, table of
    ///     contents or cover, and its reading order holds only the HREF and
    ///     the media type of each file. Set to false to open a large package
    ///     faster, or to limit the number of requests sent when streaming a
    ///     remote audiobook package. A standalone audio file is always read.
    public init(
        assetRetriever: AssetRetriever,
        metadataReader: AudioMetadataReader = DefaultAudioMetadataReader(),
        readsContainerEntriesMetadata: Bool = false
    ) {
        self.assetRetriever = assetRetriever
        self.metadataReader = metadataReader
        self.readsContainerEntriesMetadata = readsContainerEntriesMetadata
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
            readsMetadata: true,
            warnings: warnings
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
                    readsMetadata: readsContainerEntriesMetadata,
                    warnings: warnings
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
        readsMetadata: Bool,
        warnings: WarningLogger?
    ) async -> Result<Publication.Builder, PublicationParseError> {
        guard !readingOrder.isEmpty else {
            return .failure(.reading(.decoding("No audio resources found in the publication")))
        }

        var metadata = [AudioMetadata?](repeating: nil, count: readingOrder.count)
        if readsMetadata {
            switch await readMetadata(of: readingOrder, in: container, warnings: warnings) {
            case let .success(value):
                metadata = value
            case let .failure(error):
                return .failure(.reading(error))
            }
        }

        let manifest = AudioManifestBuilder().build(
            entries: zip(readingOrder, metadata).map { file, metadata in
                AudioManifestBuilder.Entry(url: file.0, format: file.1, metadata: metadata)
            },
            warnings: warnings
        )

        // The cover is the first one in reading order.
        let cover = metadata.lazy.compactMap { $0?.cover }.first

        return .success(Publication.Builder(
            manifest: manifest,
            container: container,
            servicesBuilder: .init(
                cover: cover.map { EmbeddedCoverService.makeFactory(data: $0.data, mediaType: $0.mediaType) },
                locator: AudioLocatorService.makeFactory()
            )
        ))
    }

    /// Reads the metadata of the given audio files, a batch at a time.
    ///
    /// The metadata of a file is nil when it could not be read. A batch asks
    /// for the covers only while none was found, so the files of the batch
    /// holding the first cover may have one too.
    private func readMetadata(
        of files: [(AnyURL, Format)],
        in container: Container,
        warnings: WarningLogger?
    ) async -> ReadResult<[AudioMetadata?]> {
        var metadata: [AudioMetadata?] = []

        for start in stride(from: 0, to: files.count, by: metadataBatchSize) {
            let batch = files[start ..< min(start + metadataBatchSize, files.count)]
            let includesCover = !metadata.contains { $0?.cover != nil }

            switch await readMetadata(ofBatch: batch, in: container, includesCover: includesCover) {
            case let .success(results):
                // The warnings are logged in reading order.
                for ((url, _), result) in zip(batch, results) {
                    if case let .failure(.reading(.decoding(error))) = result {
                        warnings?.log(AudioMetadataWarning.undecodableMetadata(href: url, reason: String(describing: error)))
                    }
                    metadata.append(try? result.get())
                }
            case let .failure(error):
                return .failure(error)
            }
        }

        return .success(metadata)
    }

    /// Reads the metadata of the given audio files at the same time.
    ///
    /// Returns the outcome of each file when the reader read it, does not
    /// support it or cannot interpret its content. Any other error cancels
    /// the remaining reads and is a failure.
    private func readMetadata(
        ofBatch batch: ArraySlice<(AnyURL, Format)>,
        in container: Container,
        includesCover: Bool
    ) async -> ReadResult<[Result<AudioMetadata, AudioMetadataReadError>]> {
        await withTaskGroup(of: (Int, Result<AudioMetadata, AudioMetadataReadError>).self) { group in
            for (offset, (url, format)) in batch.enumerated() {
                group.addTask { [metadataReader] in
                    guard let resource = container[url] else {
                        return (offset, .failure(.resourceNotSupported))
                    }
                    let request = AudioMetadataRequest(resource: resource, format: format, includesCover: includesCover)
                    return await (offset, metadataReader.read(request))
                }
            }

            var results = [Result<AudioMetadata, AudioMetadataReadError>](repeating: .failure(.resourceNotSupported), count: batch.count)
            for await (offset, result) in group {
                switch result {
                case .success, .failure(.resourceNotSupported), .failure(.reading(.decoding)):
                    results[offset] = result
                case let .failure(.reading(error)):
                    // The remaining reads of the batch are awaited before the
                    // group returns.
                    group.cancelAll()
                    return .failure(error)
                }
            }
            return .success(results)
        }
    }
}
