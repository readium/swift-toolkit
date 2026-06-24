//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Default implementation of ``FormatSniffer`` guessing as well as possible all
/// formats known by Readium.
public final class DefaultFormatSniffer: FormatSniffer {
    private let sniffer: CompositeFormatSniffer

    /// - Parameters:
    ///   - xmlDocumentFactory: Used to parse XML content when sniffing formats that require
    ///     XML inspection. Defaults to `DefaultXMLDocumentFactory()`.
    ///   - additionalSniffers: Additional sniffers to be used to guess content format.
    public init(
        xmlDocumentFactory: XMLDocumentFactory = DefaultXMLDocumentFactory(),
        additionalSniffers: [FormatSniffer] = []
    ) {
        sniffer = CompositeFormatSniffer(additionalSniffers + [
            JSONFormatSniffer(),
            OPDSFormatSniffer(),
            RWPMFormatSniffer(),
            LCPLicenseFormatSniffer(),

            XMLFormatSniffer(),
            HTMLFormatSniffer(),

            ZIPFormatSniffer(),
            RARFormatSniffer(),
            RPFFormatSniffer(),
            EPUBFormatSniffer(xmlDocumentFactory: xmlDocumentFactory),
            ZABFormatSniffer(),
            ComicFormatSniffer(),

            LanguageFormatSniffer(),
            PDFFormatSniffer(),
            AudioFormatSniffer(),
            BitmapFormatSniffer(),
        ])
    }

    public func sniffHints(_ hints: FormatHints) -> Format? {
        sniffer.sniffHints(hints)
    }

    public func sniffBlob(_ blob: FormatSnifferBlob, refining format: Format) async -> ReadResult<Format?> {
        await sniffer.sniffBlob(blob, refining: format)
    }

    public func sniffContainer<C: Container>(_ container: C, refining format: Format) async -> ReadResult<Format?> {
        await sniffer.sniffContainer(container, refining: format)
    }
}
