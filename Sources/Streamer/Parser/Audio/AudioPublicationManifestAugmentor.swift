//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import AVFoundation
import Foundation
import ReadiumShared
import UIKit

/// Implements a strategy to augment a `Manifest` of an audio publication with additional metadata and
/// cover, for example by looking into the audio files metadata.
public protocol AudioPublicationManifestAugmentor {
    func augment(_ baseManifest: Manifest, using container: Container) async -> AudioPublicationAugmentedManifest
}

public struct AudioPublicationAugmentedManifest {
    public var manifest: Manifest
    public var cover: UIImage?

    public init(manifest: Manifest, cover: UIImage? = nil) {
        self.manifest = manifest
        self.cover = cover
    }
}

/// An `AudioPublicationManifestAugmentor` using AVFoundation to retrieve the audio metadata.
///
/// It will only work for local publications (file://).
public final class AVAudioPublicationManifestAugmentor: AudioPublicationManifestAugmentor {
    public init() {}

    public func augment(_ manifest: Manifest, using container: Container) async -> AudioPublicationAugmentedManifest {
        let avAssets = manifest.readingOrder.map { link in
            container[link.url()]?.sourceURL?.fileURL
                .map { AVURLAsset(url: $0.url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true]) }
        }
        var manifest = manifest
        manifest.readingOrder = zip(manifest.readingOrder, avAssets).map { link, avAsset in
            guard let avAsset = avAsset else { return link }
            var link = link
            link.title = avAsset.metadata.filter([.commonIdentifierTitle]).first(where: { $0.stringValue })
            link.duration = avAsset.duration.seconds
            return link
        }
        let avMetadata = avAssets.compactMap { $0?.metadata }.reduce([], +)
        var metadata = manifest.metadata
        metadata.localizedTitle = avMetadata.filter([.commonIdentifierTitle, .id3MetadataAlbumTitle]).first(where: { $0.stringValue })?.localizedString ?? manifest.metadata.localizedTitle
        metadata.localizedSubtitle = avMetadata.filter([.id3MetadataSubTitle, .iTunesMetadataTrackSubTitle]).first(where: { $0.stringValue })?.localizedString
        metadata.modified = avMetadata.filter([.commonIdentifierLastModifiedDate]).first(where: { $0.dateValue })
        metadata.published = avMetadata.filter([.commonIdentifierCreationDate, .id3MetadataDate]).first(where: { $0.dateValue })
        metadata.languages = avMetadata.filter([.commonIdentifierLanguage, .id3MetadataLanguage]).compactMap(\.stringValue).removingDuplicates()
        metadata.subjects = avMetadata.filter([.commonIdentifierSubject]).compactMap(\.stringValue).removingDuplicates().map { Subject(name: $0) }
        metadata.authors = avMetadata.filter([.commonIdentifierAuthor, .iTunesMetadataAuthor]).compactMap(\.stringValue).removingDuplicates().map { Contributor(name: $0) }
        metadata.artists = avMetadata.filter([.commonIdentifierArtist, .id3MetadataOriginalArtist, .iTunesMetadataArtist, .iTunesMetadataOriginalArtist]).compactMap(\.stringValue).removingDuplicates().map { Contributor(name: $0) }
        metadata.illustrators = avMetadata.filter([.iTunesMetadataAlbumArtist]).compactMap(\.stringValue).removingDuplicates().map { Contributor(name: $0) }
        metadata.contributors = avMetadata.filter([.commonIdentifierContributor]).compactMap(\.stringValue).removingDuplicates().map { Contributor(name: $0) }
        metadata.publishers = avMetadata.filter([.commonIdentifierPublisher, .id3MetadataPublisher, .iTunesMetadataPublisher]).compactMap(\.stringValue).removingDuplicates().map { Contributor(name: $0) }
        metadata.description = avMetadata.filter([.commonIdentifierDescription, .iTunesMetadataDescription]).first?.stringValue
        metadata.duration = avAssets.reduce(0) { duration, avAsset in
            guard let duration = duration, let avAsset = avAsset else { return nil }
            return duration + avAsset.duration.seconds
        }
        manifest.metadata = metadata
        let cover = avMetadata.filter([.commonIdentifierArtwork, .id3MetadataAttachedPicture, .iTunesMetadataCoverArt]).first(where: { $0.dataValue.flatMap(UIImage.init(data:)) })
        return .init(manifest: manifest, cover: cover)
    }
}

private extension [AVMetadataItem] {
    func filter(_ identifiers: [AVMetadataIdentifier]) -> [AVMetadataItem] {
        identifiers.flatMap { AVMetadataItem.metadataItems(from: self, filteredByIdentifier: $0) }
    }
}
