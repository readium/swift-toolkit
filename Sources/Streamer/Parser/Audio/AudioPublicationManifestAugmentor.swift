//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared

@available(*, unavailable, message: "Implement an `AudioMetadataReader` instead, which reads the metadata of one audio file.")
public protocol AudioPublicationManifestAugmentor: Sendable {}

@available(*, unavailable, message: "An `AudioMetadataReader` returns an `AudioMetadata` for each audio file instead.")
public struct AudioPublicationAugmentedManifest: Sendable {}

@available(*, unavailable, message: "`AudioParser` reads the audio metadata with a `DefaultAudioMetadataReader` instead.")
public final class AVAudioPublicationManifestAugmentor: Sendable {}

public extension AudioParser {
    @available(*, unavailable, message: "Use `init(assetRetriever:metadataReader:readsContainerEntriesMetadata:)` with an `AudioMetadataReader` instead.")
    convenience init(assetRetriever: AssetRetriever, manifestAugmentor: AudioPublicationManifestAugmentor) {
        fatalError()
    }
}
