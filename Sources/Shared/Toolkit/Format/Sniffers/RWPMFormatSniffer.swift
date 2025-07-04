//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Sniffs a Readium Web Publication Manifest.
public struct RWPMFormatSniffer: FormatSniffer {
    public init() {}

    public func sniffHints(_ hints: FormatHints) -> Format? {
        if hints.hasMediaType("application/webpub+json") {
            return webpub
        } else if hints.hasMediaType("application/audiobook+json") {
            return audiobook
        } else if hints.hasMediaType("application/divina+json") {
            return divina
        }

        return nil
    }

    public func sniffBlob(_ blob: FormatSnifferBlob, refining format: Format) async -> ReadResult<Format?> {
        guard format.conformsTo(.json) else {
            return .success(nil)
        }

        return await blob.readAsJSON()
            .map {
                guard
                    let json = $0,
                    let manifest = try? Manifest(json: json)
                else {
                    return nil
                }

                if manifest.conforms(to: .audiobook) {
                    return audiobook
                } else if manifest.conforms(to: .divina) {
                    return divina
                } else if manifest.linkWithRel(.`self`)?.mediaType?.matches(.readiumWebPubManifest) == true {
                    return webpub
                } else {
                    return nil
                }
            }
    }

    private let webpub = Format(
        specifications: .json, .rwpm,
        mediaType: .readiumWebPubManifest,
        fileExtension: "json"
    )

    private let audiobook = Format(
        specifications: .json, .rwpm,
        mediaType: .readiumAudiobookManifest,
        fileExtension: "json"
    )

    private let divina = Format(
        specifications: .json, .rwpm,
        mediaType: .divinaManifest,
        fileExtension: "json"
    )
}
