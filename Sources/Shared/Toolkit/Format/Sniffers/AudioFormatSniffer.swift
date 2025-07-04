//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Sniffs audio formats.
public class AudioFormatSniffer: FormatSniffer {
    public init() {}

    public func sniffHints(_ hints: FormatHints) -> Format? {
        if hints.hasFileExtension("aac") || hints.hasMediaType("audio/aac") {
            return Format(specifications: .aac, mediaType: .aac, fileExtension: "aac")
        }
        if hints.hasFileExtension("aiff", "aif", "aifc") || hints.hasMediaType("audio/aiff", "audio/x-aiff") {
            return Format(specifications: .aiff, mediaType: .aiff, fileExtension: "aiff")
        }
        if hints.hasFileExtension("flac") || hints.hasMediaType("audio/flac") {
            return Format(specifications: .flac, mediaType: .flac, fileExtension: "flac")
        }
        if hints.hasFileExtension("mp3") || hints.hasMediaType("audio/mpeg") {
            return Format(specifications: .mp3, mediaType: .mp3, fileExtension: "mp3")
        }
        if hints.hasFileExtension("mp4", "m4a", "m4b", "m4p", "m4r", "alac") || hints.hasMediaType("audio/mp4") {
            return Format(specifications: .mp4, mediaType: .mp4, fileExtension: "mp4")
        }
        if hints.hasFileExtension("ogg", "oga", "mogg") || hints.hasMediaType("audio/ogg") {
            return Format(specifications: .ogg, mediaType: .ogg, fileExtension: "ogg")
        }
        if hints.hasFileExtension("opus") || hints.hasMediaType("audio/opus") {
            return Format(specifications: .opus, mediaType: .opus, fileExtension: "opus")
        }
        if hints.hasFileExtension("wav", "wave") || hints.hasMediaType("audio/wav", "audio/x-wav", "audio/wave") {
            return Format(specifications: .wav, mediaType: .wav, fileExtension: "wav")
        }
        if hints.hasFileExtension("webm") || hints.hasMediaType("audio/webm") {
            return Format(specifications: .webm, mediaType: .webmAudio, fileExtension: "webm")
        }
        return nil
    }
}
