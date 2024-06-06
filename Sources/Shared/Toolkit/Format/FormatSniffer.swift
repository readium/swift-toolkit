//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public protocol HintsFormatSniffer {
    /// Tries to guess a `Format` from media type and file extension hints.
    func sniffHints(_ hints: FormatHints) -> Format?
}

public protocol ContentFormatSniffer {
    /// Tries to refine the given `format` by sniffing a `blob`.
    func sniffBlob(_ blob: FormatSnifferBlob, refining format: Format) async -> ReadResult<Format>

    /// Tries to refine the given `format` by sniffing a `container`.
    func sniffContainer<C: Container>(_ container: C, refining format: Format) async -> ReadResult<Format>
}

public protocol FormatSniffer: HintsFormatSniffer, ContentFormatSniffer {}

public extension FormatSniffer {
    func sniffHints(_ hints: FormatHints) -> Format? {
        nil
    }

    func sniffBlob(_ blob: FormatSnifferBlob, refining format: Format) async -> ReadResult<Format> {
        .success(format)
    }

    func sniffContainer<C: Container>(_ container: C, refining format: Format) async -> ReadResult<Format> {
        .success(format)
    }
}

/// Bundle of media type and file extension hints for the `FormatHintsSniffer`.
public struct FormatHints {
    public var mediaTypes: [MediaType]
    public var fileExtensions: [FileExtension]

    public init(mediaTypes: [MediaType] = [], fileExtensions: [FileExtension] = []) {
        self.mediaTypes = mediaTypes
        self.fileExtensions = fileExtensions
    }

    public init(mediaType: MediaType? = nil, fileExtension: FileExtension? = nil) {
        mediaTypes = Array(ofNotNil: mediaType)
        fileExtensions = Array(ofNotNil: fileExtension)
    }

    /// Returns whether this context has any of the given file extensions,
    /// ignoring case.
    public func hasFileExtension(_ candidates: String...) -> Bool {
        let candidates = candidates.map { $0.lowercased() }
        return fileExtensions.contains { hints in
            candidates.contains(hints.rawValue)
        }
    }

    /// Returns whether this context has any of the given media type, ignoring
    /// case and extra parameters.
    ///
    /// Implementation note: Use `MediaType` to handle the comparison to avoid
    /// edge cases.
    public func hasMediaType(_ candidates: String...) -> Bool {
        let candidates = candidates.compactMap { MediaType($0) }
        for candidate in candidates {
            if mediaTypes.contains(where: { candidate.contains($0) }) {
                return true
            }
        }
        return false
    }
}
