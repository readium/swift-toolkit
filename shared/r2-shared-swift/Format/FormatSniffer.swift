//
//  FormatSniffer.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 10/04/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

public extension Format {
    
    /// Determines if the provided content matches a known format.
    ///
    /// Sniffing a format is done in two rounds, because we want to give an opportunity to all
    /// sniffers to return a `Format` quickly before inspecting the content itself:
    /// * *Light Sniffing* checks only the provided file extension or media type hints.
    /// * *Heavy Sniffing* reads the bytes to perform more advanced sniffing.
    ///
    /// - Parameter context: Holds the file metadata and cached content, which are shared among the
    ///   sniffers.
    /// - Parameter inspectingContent: Triggers a heavy sniffing when true.
    typealias Sniffer = (_ context: FormatSnifferContext, _ inspectingContent: Bool) -> Format?

    /// Resolves a format from file extension and media type hints, without checking the actual
    /// content.
    static func of(mediaTypes: [String] = [], fileExtensions: [String] = [], sniffers: [Sniffer] = defaultSniffers) -> Format? {
        let context = FormatMetadataSnifferContext(mediaTypes: mediaTypes, fileExtensions: fileExtensions)
        return of(context, sniffers: sniffers)
    }
    
    /// Resolves a format from a local file path.
    /// **Warning**: This API should never be called from the UI thread.
    static func of(_ file: URL, mediaTypes: [String] = [], fileExtensions: [String] = [], sniffers: [Sniffer] = defaultSniffers) -> Format? {
        warnIfMainThread()
        let context = FormatFileSnifferContext(file: file, mediaTypes: mediaTypes, fileExtensions: fileExtensions)
        return of(context, sniffers: sniffers)
    }
    
    /// Resolves a format from bytes, e.g. from an HTTP response.
    /// **Warning**: This API should never be called from the UI thread.
    static func of(_ data: @escaping () -> Data, mediaTypes: [String] = [], fileExtensions: [String] = [], sniffers: [Sniffer] = defaultSniffers) -> Format? {
        warnIfMainThread()
        let context = FormatDataSnifferContext(data: data, mediaTypes: mediaTypes, fileExtensions: fileExtensions)
        return of(context, sniffers: sniffers)
    }
    
    /// Resolves a format from a sniffer context.
    private static func of(_ context: FormatSnifferContext, sniffers: [Sniffer] = defaultSniffers) -> Format? {
        // Light sniffing
        for sniffer in sniffers {
            if let format = sniffer(context, /* inspectingContent: */ false) {
                return format
            }
        }
        // Heavy sniffing
        for sniffer in sniffers {
            if let format = sniffer(context, /* inspectingContent: */ true) {
                return format
            }
        }
        
        return nil
    }
    
    
    // MARK: Sniffers
    
    /// The default sniffers provided by Readium 2 to resolve a `Format`.
    ///
    /// You can register additional sniffers globally by modifying this list.
    /// The sniffers order is crucial, because some formats are subsets of other formats:
    static var defaultSniffers: [Sniffer] = [
        sniffHTML, sniffOPDS1, sniffOPDS2,
        sniffLCPLicense, sniffLCPProtectedPublication,
        sniffWebPub, sniffW3CWPUB, sniffEPUB, sniffLPF, sniffZIP, sniffPDF,
        sniffBitmap
    ]

    /// Sniffs an HTML document.
    private static func sniffHTML(context: FormatSnifferContext, inspectingContent: Bool) -> Format? {
        if context.hasFileExtension("htm", "html", "xht", "xhtml") || context.hasMediaType("text/html", "application/xhtml+xml") {
            return .HTML
        }
        return nil
    }
    
    /// Sniffs an OPDS 1 document.
    private static func sniffOPDS1(context: FormatSnifferContext, inspectingContent: Bool) -> Format? {
        if context.hasMediaType("application/atom+xml;type=entry;profile=opds-catalog") {
            return .OPDS1Entry
        }
        if context.hasMediaType("application/atom+xml;profile=opds-catalog") {
            return .OPDS1Feed
        }
        return nil
    }
    
    /// Sniffs an OPDS 2 document.
    private static func sniffOPDS2(context: FormatSnifferContext, inspectingContent: Bool) -> Format? {
        if context.hasMediaType("application/opds+json") {
            return .OPDS2Feed
        }
        if context.hasMediaType("application/opds-publication+json") {
            return .OPDS2Publication
        }
        if inspectingContent, let rwpm = context.contentAsRWPM {
            if rwpm.link(withRel: "self")?.type == "application/opds+json" {
                return .OPDS2Feed
            }
            if rwpm.link(withRelMatching: { $0.hasPrefix("http://opds-spec.org/acquisition") }) != nil {
                return .OPDS2Publication
            }
        }
        return nil
    }
    
    /// Sniffs an LCP License Document.
    private static func sniffLCPLicense(context: FormatSnifferContext, inspectingContent: Bool) -> Format? {
        if context.hasFileExtension("lcpl") || context.hasMediaType("application/vnd.readium.lcp.license.v1.0+json") {
            return .LCPLicense
        }
        if inspectingContent, let json = context.contentAsJSON as? [String: Any] {
            if Set(json.keys).isSuperset(of: ["id", "issued", "provider", "encryption"]) {
                return .LCPLicense
            }
        }
        return nil
    }
    
    /// Sniffs an LCP Protected Publication.
    private static func sniffLCPProtectedPublication(context: FormatSnifferContext, inspectingContent: Bool) -> Format? {
        if context.hasFileExtension("lcpa") || context.hasMediaType("application/audiobook+lcp") {
            return .LCPProtectedAudiobook
        }
        if context.hasFileExtension("lcpdf") || context.hasMediaType("application/pdf+lcp") {
            return .LCPProtectedPDF
        }
        return nil
    }
    
    /// Sniffs a Readium Web Publication.
    private static func sniffWebPub(context: FormatSnifferContext, inspectingContent: Bool) -> Format? {
        if context.hasFileExtension("audiobook") || context.hasMediaType("application/audiobook+zip") {
            return .Audiobook
        }
        if context.hasMediaType("application/audiobook+json") {
            return .AudiobookManifest
        }
        
        if context.hasFileExtension("divina") || context.hasMediaType("application/divina+zip") {
            return .DiViNa
        }
        if context.hasMediaType("application/divina+json") {
            return .DiViNaManifest
        }
        
        if context.hasFileExtension("webpub") || context.hasMediaType("application/webpub+zip") {
            return .WebPub
        }
        if context.hasMediaType("application/webpub+json") {
            return .WebPubManifest
        }
        
        if inspectingContent, let rwpm = context.contentAsRWPM {
            if rwpm.metadata.type == "http://schema.org/Audiobook" {
                return .AudiobookManifest
            }
            if rwpm.allReadingOrderIsBitmap {
                return .DiViNaManifest
            }
            if rwpm.link(withRel: "self")?.type == "application/webpub+json" {
                return .WebPubManifest
            }
        }
        
        return nil
    }
    
    /// Sniffs a W3C Web Publication Manifest.
    private static func sniffW3CWPUB(context: FormatSnifferContext, inspectingContent: Bool) -> Format? {
        if inspectingContent,
            let json = context.contentAsJSON as? [String: Any],
            let context = json["@context"] as? [Any],
            context.contains(where: { ($0 as? String) == "https://www.w3.org/ns/wp-context" })
        {
            return .W3CWPUBManifest
        }
        return nil
    }

    /// Sniffs an EPUB publication.
    /// Reference: https://www.w3.org/publishing/epub3/epub-ocf.html#sec-zip-container-mime
    private static func sniffEPUB(context: FormatSnifferContext, inspectingContent: Bool) -> Format? {
        if context.hasFileExtension("epub") || context.hasMediaType("application/epub+zip") {
            return .EPUB
        }
        return nil
    }
    
    /// Sniffs a Lightweight Packaging Format (LPF).
    /// References:
    /// * https://www.w3.org/TR/lpf/
    /// * https://www.w3.org/TR/pub-manifest/
    private static func sniffLPF(context: FormatSnifferContext, inspectingContent: Bool) -> Format? {
        if context.hasFileExtension("lpf") || context.hasMediaType("application/lpf+zip") {
            return .LPF
        }
        return nil
    }

    /// Sniffs a simple ZIP-based format, like Comic Book Archive or Zipped Audio Book.
    /// Reference: https://wiki.mobileread.com/wiki/CBR_and_CBZ
    private static func sniffZIP(context: FormatSnifferContext, inspectingContent: Bool) -> Format? {
        if context.hasFileExtension("cbz") || context.hasMediaType("application/vnd.comicbook+zip", "application/x-cbz", "application/x-cbr") {
            return .CBZ
        }
        if context.hasFileExtension("zab") {
            return .ZAB
        }
        return nil
    }

    /// Sniffs a PDF document.
    /// Reference: https://www.loc.gov/preservation/digital/formats/fdd/fdd000123.shtml
    private static func sniffPDF(context: FormatSnifferContext, inspectingContent: Bool) -> Format? {
        if context.hasFileExtension("pdf") || context.hasMediaType("application/pdf") {
            return .PDF
        }
        if inspectingContent, context.readFileSignature(length: 5) == "%PDF-" {
            return .PDF
        }
        return nil
    }
    
    /// Sniffs a bitmap image.
    private static func sniffBitmap(context: FormatSnifferContext, inspectingContent: Bool) -> Format? {
        if context.hasFileExtension("bmp", "dib") || context.hasMediaType("image/bmp", "image/x-bmp") {
            return .BMP
        }
        if context.hasFileExtension("gif") || context.hasMediaType("image/gif") {
            return .GIF
        }
        if context.hasFileExtension("jpg", "jpeg", "jpe", "jif", "jfif", "jfi") || context.hasMediaType("image/jpeg") {
            return .JPEG
        }
        if context.hasFileExtension("png") || context.hasMediaType("image/png") {
            return .PNG
        }
        if context.hasFileExtension("tiff", "tif") || context.hasMediaType("image/tiff", "image/tiff-fx") {
            return .TIFF
        }
        if context.hasFileExtension("webp") || context.hasMediaType("image/webp") {
            return .WebP
        }
        return nil
    }

}

private extension Publication {
    
    func link(withRelMatching predicate: (String) -> Bool) -> Link? {
        for link in links {
            for rel in link.rels {
                if predicate(rel) {
                    return link
                }
            }
        }
        return nil
    }
    
}
