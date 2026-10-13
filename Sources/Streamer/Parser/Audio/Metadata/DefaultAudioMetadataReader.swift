//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import AVFoundation
import CoreMedia
import Foundation
import ReadiumShared
import UniformTypeIdentifiers

/// An ``AudioMetadataReader`` reading the metadata with AVFoundation.
///
/// It reads:
/// - A resource stored as a file on the device, directly from the file.
/// - Any other resource which can seek, such as the entry of an archive
///   stored without compression or a remote file, through a resource loader.
///   Reading a remote resource sends several requests.
///
/// The entry of an archive which is compressed fails with
/// `.resourceNotSupported`. It cannot seek: reaching an offset means
/// decompressing everything before it, while AVFoundation reads the end of a
/// file before coming back to its start.
///
/// It takes the values AVFoundation gives decoded and does not parse the atoms
/// and the frames itself, except the Nero `chpl` atom.
public final class DefaultAudioMetadataReader: AudioMetadataReader {
    public init() {}

    public func read(_ request: AudioMetadataRequest) async -> Result<AudioMetadata, AudioMetadataReadError> {
        let resource = request.resource

        // AVFoundation does not tell a resource which cannot be accessed from
        // a resource which cannot be interpreted.
        if case let .failure(error) = await resource.estimatedLength() {
            return .failure(.reading(error))
        }

        // Precise timing (`AVURLAssetPreferPreciseDurationAndTimingKey`) is
        // never requested, as it reads the whole of an MP3 file without a
        // Xing header. The duration of such a file is an estimate.
        if let file = resource.sourceURL?.fileURL {
            return await read(AVURLAsset(url: file.url), for: request)
        }

        // A compressed entry cannot seek.
        switch await resource.properties() {
        case let .success(properties):
            guard properties.archive?.isEntryCompressed != true else {
                return .failure(.resourceNotSupported)
            }
        case let .failure(error):
            return .failure(.reading(error))
        }

        // The content type of the asset comes from the media type.
        guard let mediaType = request.format.mediaType, mediaType.uti != nil else {
            return .failure(.resourceNotSupported)
        }

        // The loader serves a single resource, whatever the HREF.
        let loadingError = Mutex<ReadError?>(nil)
        let loader = ResourceAssetLoader { href in
            .init(href: href, resource: resource, mediaType: mediaType)
        }
        loader.onLoadingError = { _, error in
            loadingError.withLock { $0 = $0 ?? error }
        }
        guard let asset = try? loader.makeAsset(for: assetHREF) else {
            return .failure(.resourceNotSupported)
        }

        let result = await read(asset, for: request)

        // AVFoundation does not always abandon its last request, whose stream
        // would keep reading the resource after this method returned.
        asset.cancelLoading()
        await loader.invalidate()

        // The error of the resource tells why the reading failed, which the
        // one of AVFoundation does not. It is ignored after a success: a
        // request that AVFoundation no longer needs may fail once it has
        // read everything.
        if case .failure = result, let error = loadingError.withLock({ $0 }) {
            return .failure(.reading(error))
        }
        return result
    }

    /// HREF of the asset served by a resource loader.
    private let assetHREF = AnyURL(string: "audio")!

    /// Reads the metadata of the resource of `request`, which is served by
    /// the given `asset`.
    private func read(_ asset: AVURLAsset, for request: AudioMetadataRequest) async -> Result<AudioMetadata, AudioMetadataReadError> {
        do {
            return try await withTaskCancellationHandler {
                try await .success(metadata(of: asset, includesCover: request.includesCover))
            } onCancel: {
                asset.cancelLoading()
            }
        } catch {
            if Task.isCancelled || error is CancellationError {
                return .failure(.reading(.cancelled))
            }
            guard request.format.isDeclaredByAVFoundation else {
                return .failure(.resourceNotSupported)
            }
            return .failure(.reading(.decoding(error)))
        }
    }

    private let decoder = AudioMetadataDecoder()

    private func metadata(of asset: AVURLAsset, includesCover: Bool) async throws -> AudioMetadata {
        // The duration is not a number when it is unknown.
        let duration = try await asset.load(.duration).seconds.orNilIfNotPositive()
        let tags = try await Tags(asset: asset)
        // The data rate is 0 when it is unknown, as for an MP3 file without a
        // Xing header.
        let dataRate = try await asset.loadTracks(withMediaType: .audio).first?.load(.estimatedDataRate) ?? 0
        let chapters = try await chapters(of: asset, tags: tags, fileDuration: duration)
        let cover = try await includesCover ? cover(from: tags) : nil

        return AudioMetadata(
            title: tags.first(.mp4("©nam"), .id3("TIT2")),
            album: tags.first(.mp4("©alb"), .id3("TALB")),
            subtitle: tags.first(.mp4("©st3"), .freeform("SUBTITLE"), .id3("TIT3")),
            albumArtists: tags[.mp4("aART")] + tags[.id3("TPE2")].flatMap(decoder.id3Values(from:)),
            artists: tags[.mp4("©ART")] + tags[.id3("TPE1")].flatMap(decoder.id3Values(from:)),
            narrators: tags[.mp4("©nrt")] + tags[.userDefined("NARRATOR")].flatMap(decoder.id3Values(from:)),
            composers: tags[.mp4("©wrt")] + tags[.id3("TCOM")].flatMap(decoder.id3Values(from:)),
            movementName: tags.first(.mp4("©mvn")),
            movementIndex: tags[.mp4("©mvi")].first(where: decoder.seriesPosition(from:)),
            series: tags.first(.freeform("SERIES"), .userDefined("SERIES")),
            seriesPosition: tags[.freeform("SERIES-PART"), .userDefined("SERIES-PART")].first(where: decoder.seriesPosition(from:)),
            publishers: tags[.mp4("©pub")] + tags[.id3("TPUB")].flatMap(decoder.id3Values(from:)),
            releaseDate: tags[.id3("TDRL")].first(where: decoder.date(from:)),
            // AVFoundation only gives a correct date value for a complete
            // timestamp, so the text of the tag is decoded.
            date: tags[.mp4("©day"), .id3("TDRC"), .id3("TYER")].first(where: decoder.date(from:)),
            genres: tags[.mp4("©gen")].flatMap(decoder.genres(from:)) + tags[.id3("TCON")].flatMap(decoder.id3Genres(from:)),
            description: tags.first(.mp4("ldes"), .userDefined("DESCRIPTION")),
            summary: tags.first(.mp4("desc"), .id3("TDES")),
            comment: tags.first(.mp4("©cmt"), .comment),
            languages: (tags[.freeform("LANGUAGE")] + tags[.id3("TLAN")].flatMap(decoder.id3Values(from:)))
                .compactMap(decoder.language(from:)),
            isbn: tags.first(.freeform("ISBN"), .userDefined("ISBN")),
            sortAlbum: tags.first(.mp4("soal"), .id3("TSOA")),
            sortTitle: tags.first(.mp4("sonm"), .id3("TSOT")),
            cover: cover,
            duration: duration,
            bitrate: (Double(dataRate) / 1000).orNilIfNotPositive(),
            chapters: chapters
        )
    }

    /// Returns the chapters of the QuickTime chapter track or of the ID3
    /// `CHAP` frames, or else the ones of the Nero `chpl` atom, ordered by
    /// start time.
    private func chapters(of asset: AVURLAsset, tags: Tags, fileDuration: TimeInterval?) async throws -> [AudioMetadata.Chapter] {
        var chapters: [AudioMetadata.Chapter] = []

        // The chapter titles often have the undetermined locale (`und`),
        // which matches no preferred language. The first available locale is
        // used instead.
        if let locale = try await asset.load(.availableChapterLocales).first {
            for group in try await asset.loadChapterMetadataGroups(withTitleLocale: locale, containingItemsWithCommonKeys: []) {
                let start = group.timeRange.start.seconds
                guard start.isFinite else {
                    continue
                }
                let title = try await group.items.first { $0.commonKey == .commonKeyTitle }?.load(.stringValue)
                chapters.append(AudioMetadata.Chapter(
                    title: title?.orNilIfBlank(),
                    start: start,
                    duration: group.timeRange.duration.seconds.orNilIfNotPositive()
                ))
            }

            // AVFoundation follows the order of the ID3 `CTOC` frame.
            chapters.sort { $0.start < $1.start }
        }

        // AVFoundation gives the Nero atom as raw data.
        if chapters.isEmpty, let data = try await tags.items(.neroChapters).first?.load(.dataValue) {
            chapters = decoder.neroChapters(from: data, fileDuration: fileDuration)
        }

        return chapters
    }

    /// Returns the picture of the MP4 `covr` atom, or else of the ID3 `APIC`
    /// frames: the first front cover, or else the first picture.
    private func cover(from tags: Tags) async throws -> AudioMetadata.Cover? {
        var cover = tags.items(.mp4Cover).first

        if cover == nil {
            var pictures: [AVMetadataItem] = []
            for picture in tags.items(.id3Picture) {
                let attributes = try await picture.load(.extraAttributes) ?? [:]

                // A linked picture holds a URL in place of the image.
                guard attributes[.mimeType] as? String != "-->" else {
                    continue
                }
                if attributes[.pictureType] as? String == "Cover (front)" {
                    cover = picture
                    break
                }
                pictures.append(picture)
            }
            cover = cover ?? pictures.first
        }

        guard let cover, let data = try await cover.load(.dataValue), !data.isEmpty else {
            return nil
        }
        return AudioMetadata.Cover(data: data, mediaType: cover.imageMediaType)
    }
}

/// Tags of an audio file, as AVFoundation gives them.
private struct Tags {
    /// Non-blank values of the text tags.
    private var strings: [Tag: [String]] = [:]

    /// Items of the tags holding data, which is only loaded on demand.
    private var dataItems: [Tag: [AVMetadataItem]] = [:]

    init(asset: AVAsset) async throws {
        for format in try await asset.load(.availableMetadataFormats) {
            for item in try await asset.loadMetadata(for: format) {
                guard let tag = try await Tag(item: item) else {
                    continue
                }

                if tag.holdsData {
                    dataItems[tag, default: []].append(item)
                } else if let string = try await item.load(.stringValue), !string.isBlank {
                    // A tag AVFoundation gives as raw data has no string
                    // value, as the ID3 `MVNM` and `MVIN` frames.
                    strings[tag, default: []].append(string)
                }
            }
        }
    }

    /// Returns the non-blank values of the given tags, listed in priority
    /// order.
    subscript(_ tags: Tag...) -> [String] {
        tags.flatMap { strings[$0] ?? [] }
    }

    /// Returns the first non-blank value of the given tags, listed in
    /// priority order.
    func first(_ tags: Tag...) -> String? {
        tags.first { strings[$0]?.first }
    }

    /// Returns the items of the given tag holding data.
    func items(_ tag: Tag) -> [AVMetadataItem] {
        dataItems[tag] ?? []
    }
}

/// A tag of an audio file, written as in the reference.
private enum Tag: Hashable {
    /// MP4 atom, such as `©nam`.
    case mp4(String)

    /// MP4 freeform atom with the mean `com.apple.iTunes`, by its name in
    /// uppercase: `----:SERIES` is `.freeform("SERIES")`.
    case freeform(String)

    /// ID3 frame, such as `TIT2`.
    case id3(String)

    /// ID3 `TXXX` frame, by its name in uppercase: `TXXX:SERIES` is
    /// `.userDefined("SERIES")`.
    case userDefined(String)

    /// ID3 `COMM` frame with an empty description.
    ///
    /// A `COMM` frame with a description may hold technical data.
    case comment

    /// Nero `chpl` atom.
    case neroChapters

    /// MP4 `covr` atom.
    static let mp4Cover = Tag.mp4("covr")

    /// ID3 `APIC` frame.
    static let id3Picture = Tag.id3("APIC")

    /// Whether the value of this tag is data, instead of text.
    var holdsData: Bool {
        self == .mp4Cover || self == .id3Picture || self == .neroChapters
    }

    /// Creates the tag of the given `item` from its identifier, such as
    /// `itsk/%A9nam`, `itlk/com.apple.iTunes.SERIES`, `id3/TIT2` or
    /// `uiso/chpl`.
    ///
    /// The common key of an item cannot be used, as it is wrong for several
    /// ID3 frames: `TIT3` is given as a description, `TCON` as a type and
    /// `TCOM` as a creator.
    init?(item: AVMetadataItem) async throws {
        guard
            let identifier = item.identifier?.rawValue,
            let separator = identifier.firstIndex(of: "/")
        else {
            return nil
        }
        let key = String(identifier[separator...].dropFirst())

        switch identifier[..<separator] {
        case "itsk":
            // The `©` of an atom name is percent-encoded as one byte.
            self = .mp4(key.replacingOccurrences(of: "%A9", with: "©"))

        case "itlk":
            let mean = "com.apple.iTunes."
            guard key.hasPrefix(mean) else {
                return nil
            }
            self = .freeform(key.dropFirst(mean.count).uppercased())

        case "id3":
            switch key {
            case "TXXX":
                self = try await .userDefined(item.info().uppercased())
            case "COMM":
                guard try await item.info().isEmpty else {
                    return nil
                }
                self = .comment
            default:
                self = .id3(key)
            }

        case "uiso" where key == "chpl":
            self = .neroChapters

        default:
            return nil
        }
    }
}

private extension AVMetadataItem {
    /// Returns the name of an ID3 `TXXX` frame, or the description of an ID3
    /// `COMM` frame.
    func info() async throws -> String {
        try await load(.extraAttributes)?[.info] as? String ?? ""
    }

    /// Media type of the image this item holds, as declared by the file: the
    /// type code of an MP4 `covr` atom, or the MIME type of an ID3 `APIC`
    /// frame, where AVFoundation takes `image/jpg` as `image/jpeg`.
    var imageMediaType: MediaType? {
        let mediaTypes: [CFString: MediaType] = [
            kCMMetadataBaseDataType_JPEG: .jpeg,
            kCMMetadataBaseDataType_PNG: .png,
        ]
        return dataType.flatMap { mediaTypes[$0 as CFString] }
    }
}

private extension AVMetadataExtraAttributeKey {
    /// MIME type of an ID3 `APIC` frame, as written in the file.
    static let mimeType = AVMetadataExtraAttributeKey(rawValue: "dataType")

    /// Picture type of an ID3 `APIC` frame, as a label such as
    /// `Cover (front)`.
    static let pictureType = AVMetadataExtraAttributeKey(rawValue: "pictureType")
}

private extension Format {
    /// Whether AVFoundation declares that it reads this format.
    ///
    /// This is only asked after a failure, to tell a defective file from a
    /// format which is not supported.
    var isDeclaredByAVFoundation: Bool {
        guard let type = mediaType?.uti.flatMap({ UTType($0) }) else {
            return false
        }
        return AVURLAsset.audiovisualTypes().contains { declared in
            UTType(declared.rawValue).map { type.conforms(to: $0) } ?? false
        }
    }
}
