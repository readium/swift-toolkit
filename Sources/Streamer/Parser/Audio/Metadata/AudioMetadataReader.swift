//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

/// Reads the metadata embedded in one audio resource.
///
/// https://github.com/readium/architecture/blob/master/streamer/parser/audio-metadata.md
public protocol AudioMetadataReader: Sendable {
    /// Reads the metadata of the resource of the given `request`.
    ///
    /// An audio resource without tags is not a failure: it gives its duration
    /// and nothing else.
    ///
    /// Fails with:
    /// - `.resourceNotSupported` when the reader cannot read this resource.
    /// - `.reading(.decoding)` when the reader supports the resource, but
    ///   failed to interpret its content.
    /// - `.reading` with another `ReadError` when the content cannot be
    ///   accessed, or when the task is cancelled.
    func read(_ request: AudioMetadataRequest) async -> Result<AudioMetadata, AudioMetadataReadError>
}

/// Inputs of an ``AudioMetadataReader``.
public struct AudioMetadataRequest: Sendable {
    /// Audio resource to read.
    public var resource: Resource

    /// Format of the resource.
    public var format: Format

    /// When false, the cover is not extracted and `AudioMetadata.cover` is nil.
    public var includesCover: Bool

    public init(resource: Resource, format: Format, includesCover: Bool = true) {
        self.resource = resource
        self.format = format
        self.includesCover = includesCover
    }
}

public enum AudioMetadataReadError: Error, Sendable {
    /// The reader cannot read the metadata of this resource.
    case resourceNotSupported

    /// An error occurred while trying to read the resource.
    case reading(ReadError)
}
