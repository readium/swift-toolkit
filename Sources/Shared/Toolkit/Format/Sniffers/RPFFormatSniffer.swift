//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Sniffs a Readium Web Publication package.
public struct RPFFormatSniffer: FormatSniffer {
    public init() {}

    public func sniffHints(_ hints: FormatHints) -> Format? {
        if hints.hasMediaType("application/audiobook+zip") || hints.hasFileExtension("audiobook") {
            return audiobook
        } else if hints.hasMediaType("application/audiobook+lcp") || hints.hasFileExtension("lcpa") {
            return audiobookLCP
        } else if hints.hasMediaType("application/pdf+lcp") || hints.hasFileExtension("lcpdf") {
            return pdfLCP
        } else if hints.hasMediaType("application/divina+zip") || hints.hasFileExtension("divina") {
            return divina
        } else if hints.hasMediaType("application/webpub+zip") || hints.hasFileExtension("webpub") {
            return webpub
        }

        return nil
    }

    public func sniffContainer<C>(_ container: C, refining format: Format) async -> ReadResult<Format?> where C: Container {
        guard let resource = container[AnyURL(path: "manifest.json")!] else {
            return .success(nil)
        }

        return await resource.readAsJSONObject()
            .map {
                guard let manifest = try? Manifest(json: $0) else {
                    return nil
                }

                let isLCPProtected =
                    container.entries.contains(AnyURL(path: "license.lcpl")!) ||
                    manifest.containsLCPScheme

                if manifest.conforms(to: .audiobook) {
                    return isLCPProtected ? audiobookLCP : audiobook
                } else if manifest.conforms(to: .divina) {
                    return isLCPProtected ? divinaLCP : divina
                } else if manifest.conforms(to: .pdf) {
                    return isLCPProtected ? pdfLCP : webpub
                } else {
                    return isLCPProtected ? webpubLCP : webpub
                }
            }
    }

    private let webpub = Format(
        specifications: .zip, .rpf,
        mediaType: .readiumWebPub,
        fileExtension: "webpub"
    )

    private let webpubLCP = Format(
        specifications: .zip, .rpf, .lcp,
        mediaType: .readiumWebPub,
        fileExtension: "webpub"
    )

    private let audiobook = Format(
        specifications: .zip, .rpf,
        mediaType: .readiumAudiobook,
        fileExtension: "audiobook"
    )

    private let audiobookLCP = Format(
        specifications: .zip, .rpf, .lcp,
        mediaType: .lcpProtectedAudiobook,
        fileExtension: "lcpa"
    )

    private let divina = Format(
        specifications: .zip, .rpf,
        mediaType: .divina,
        fileExtension: "divina"
    )

    private let divinaLCP = Format(
        specifications: .zip, .rpf, .lcp,
        mediaType: .divina,
        fileExtension: "divina"
    )

    private let pdfLCP = Format(
        specifications: .zip, .rpf, .lcp,
        mediaType: .lcpProtectedPDF,
        fileExtension: "lcpdf"
    )
}

private extension Manifest {
    var containsLCPScheme: Bool {
        readingOrder.contains { link in
            link.properties.encryption?.scheme == "http://readium.org/2014/01/lcp"
        }
    }
}
