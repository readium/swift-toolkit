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
    /// - Parameter context: Holds the file metadata and cached content, which are shared among the
    ///   sniffers.
    typealias Sniffer = (_ context: FormatSnifferContext) -> Format?

    /// Resolves a format from file extension and media type hints, without checking the actual
    /// content.
    static func of(mediaTypes: [String] = [], fileExtensions: [String] = [], sniffers: [Sniffer] = sniffers) -> Format? {
        return of(content: nil, mediaTypes: mediaTypes, fileExtensions: fileExtensions, sniffers: sniffers)
    }
    
    /// Resolves a format from a local file path.
    /// **Warning**: This API should never be called from the UI thread.
    static func of(_ file: URL, mediaTypes: [String] = [], fileExtensions: [String] = [], sniffers: [Sniffer] = sniffers) -> Format? {
        let fileExtensions = [file.pathExtension] + fileExtensions
        return of(content: FormatSnifferFileContent(file: file), mediaTypes: mediaTypes, fileExtensions: fileExtensions, sniffers: sniffers)
    }
    
    /// Resolves a format from bytes, e.g. from an HTTP response.
    /// **Warning**: This API should never be called from the UI thread.
    static func of(_ data: @escaping () -> Data, mediaTypes: [String] = [], fileExtensions: [String] = [], sniffers: [Sniffer] = sniffers) -> Format? {
        return of(content: FormatSnifferDataContent(data: data), mediaTypes: mediaTypes, fileExtensions: fileExtensions, sniffers: sniffers)
    }
    
    /// Resolves a format from a sniffer context.
    ///
    /// Sniffing a format is done in two rounds, because we want to give an opportunity to all
    /// sniffers to return a `Format` quickly before inspecting the content itself:
    /// * *Light Sniffing* checks only the provided file extension or media type hints.
    /// * *Heavy Sniffing* reads the bytes to perform more advanced sniffing.
    private static func of(content: FormatSnifferContent?, mediaTypes: [String], fileExtensions: [String], sniffers: [Sniffer]) -> Format? {
        if content != nil {
            warnIfMainThread()
        }
        
        // Light sniffing
        let context = FormatSnifferContext(mediaTypes: mediaTypes, fileExtensions: fileExtensions)
        for sniffer in sniffers {
            if let format = sniffer(context) {
                return format
            }
        }
        
        // Heavy sniffing
        if let content = content {
            let context = FormatSnifferContext(content: content, mediaTypes: mediaTypes, fileExtensions: fileExtensions)
            for sniffer in sniffers {
                if let format = sniffer(context) {
                    return format
                }
            }
        }
        
        return nil
    }
    
    
    // MARK: Sniffers
    
    /// The default sniffers provided by Readium 2 to resolve a `Format`.
    ///
    /// You can register additional sniffers globally by modifying this list.
    /// The sniffers order is important, because some formats are subsets of other formats.
    static var sniffers: [Sniffer] = [
        sniffHTML, sniffOPDS1, sniffOPDS2, sniffLCPLicense, sniffBitmap,
        sniffWebPub, sniffW3CWPUB, sniffEPUB, sniffLPF, sniffZIP, sniffPDF,
    ]

    /// Sniffs an HTML document.
    private static func sniffHTML(context: FormatSnifferContext) -> Format? {
        if context.hasFileExtension("htm", "html", "xht", "xhtml") || context.hasMediaType("text/html", "application/xhtml+xml") {
            return .HTML
        }
        if context.contentAsXML?.root?.tag?.lowercased() == "html" {
            return .HTML
        }
        return nil
    }
    
    /// Sniffs an OPDS 1 document.
    private static func sniffOPDS1(context: FormatSnifferContext) -> Format? {
        if context.hasMediaType("application/atom+xml;type=entry;profile=opds-catalog") {
            return .OPDS1Entry
        }
        if context.hasMediaType("application/atom+xml;profile=opds-catalog") {
            return .OPDS1Feed
        }
        if let xml = context.contentAsXML {
            xml.definePrefix("atom", forNamespace: "http://www.w3.org/2005/Atom")
            if xml.firstChild(xpath: "/atom:feed") != nil {
                return .OPDS1Feed
            } else if xml.firstChild(xpath: "/atom:entry") != nil {
                return .OPDS1Entry
            }
        }
        return nil
    }
    
    /// Sniffs an OPDS 2 document.
    private static func sniffOPDS2(context: FormatSnifferContext) -> Format? {
        if context.hasMediaType("application/opds+json") {
            return .OPDS2Feed
        }
        if context.hasMediaType("application/opds-publication+json") {
            return .OPDS2Publication
        }
        if let rwpm = context.contentAsRWPM {
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
    private static func sniffLCPLicense(context: FormatSnifferContext) -> Format? {
        if context.hasFileExtension("lcpl") || context.hasMediaType("application/vnd.readium.lcp.license.v1.0+json") {
            return .LCPLicense
        }
        if let json = context.contentAsJSON as? [String: Any] {
            if Set(json.keys).isSuperset(of: ["id", "issued", "provider", "encryption"]) {
                return .LCPLicense
            }
        }
        return nil
    }
    
    /// Sniffs a Readium Web Publication, protected or not by LCP.
    private static func sniffWebPub(context: FormatSnifferContext) -> Format? {
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
        
        if context.hasFileExtension("lcpa") || context.hasMediaType("application/audiobook+lcp") {
            return .LCPProtectedAudiobook
        }
        if context.hasFileExtension("lcpdf") || context.hasMediaType("application/pdf+lcp") {
            return .LCPProtectedPDF
        }
        
        /// Reads a RWPM, either from a manifest.json file, or from a manifest.json ZIP entry, if
        /// the file is a ZIP archive.
        func readRWPM() -> (isManifest: Bool, Publication)? {
            if let rwpm = context.contentAsRWPM {
                return (isManifest: true, rwpm)
            } else if let manifestData = context.readZIPEntry(at: "manifest.json"),
                let manifestJSON = try? JSONSerialization.jsonObject(with: manifestData),
                let rwpm = try? Publication(json: manifestJSON) {
                return (isManifest: false, rwpm)
            } else {
                return nil
            }
        }

        if let (isManifest, rwpm) = readRWPM() {
            let isLCPProtected = context.containsZIPEntry(at: "license.lcpl")

            if rwpm.metadata.type == "http://schema.org/Audiobook" {
                return isManifest ? .AudiobookManifest :
                    isLCPProtected ? .LCPProtectedAudiobook : .Audiobook
            }
            if rwpm.allReadingOrderIsBitmap {
                return isManifest ? .DiViNaManifest : .DiViNa
            }
            if isLCPProtected, rwpm.allReadingOrder({ $0.hasMediaType(.PDF) }) {
                return .LCPProtectedPDF
            }
            if rwpm.link(withRel: "self")?.type == "application/webpub+json" {
                return isManifest ? .WebPubManifest : .WebPub
            }
        }

        return nil
    }
    
    /// Sniffs a W3C Web Publication Manifest.
    private static func sniffW3CWPUB(context: FormatSnifferContext) -> Format? {
        if let json = context.contentAsJSON as? [String: Any],
            let context = json["@context"] as? [Any],
            context.contains(where: { ($0 as? String) == "https://www.w3.org/ns/wp-context" })
        {
            return .W3CWPUBManifest
        }
        return nil
    }

    /// Sniffs an EPUB publication.
    /// Reference: https://www.w3.org/publishing/epub3/epub-ocf.html#sec-zip-container-mime
    private static func sniffEPUB(context: FormatSnifferContext) -> Format? {
        if context.hasFileExtension("epub") || context.hasMediaType("application/epub+zip") {
            return .EPUB
        }
        if let mimetypeData = context.readZIPEntry(at: "mimetype"),
            let mimetype = String(data: mimetypeData, encoding: .ascii),
            mimetype == "application/epub+zip"
        {
            return .EPUB
        }
        return nil
    }
    
    /// Sniffs a Lightweight Packaging Format (LPF).
    /// References:
    /// * https://www.w3.org/TR/lpf/
    /// * https://www.w3.org/TR/pub-manifest/
    private static func sniffLPF(context: FormatSnifferContext) -> Format? {
        if context.hasFileExtension("lpf") || context.hasMediaType("application/lpf+zip") {
            return .LPF
        }
        if context.containsZIPEntry(at: "index.html") {
            return .LPF
        }
        if let data = context.readZIPEntry(at: "publication.json"),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let contexts = json["@context"] as? [Any],
            contexts.contains(where: {($0 as? String) == "https://www.w3.org/ns/pub-context"})
        {
            return .LPF
        }
        return nil
    }

    /// Authorized extensions for CBZ
    /// Reference: https://wiki.mobileread.com/wiki/CBR_and_CBZ
    private static let cbzExtensions = ["acbf", "bmp", "dib", "gif", "jif", "jfi", "jfif", "jpg", "jpeg", "png", "tif", "tiff", "webp", "xml"]
    
    /// Authorized extensions for ZAB (Zipped Audio Book)
    private static let zabExtensions = [
        // audio
        "aac", "aiff", "alac", "flac", "m4a", "m4b", "mp3", "ogg", "oga", "mogg", "opus", "wav", "webm",
        // playlist
        "asx", "bio", "m3u", "m3u8", "pla", "pls", "smil", "vlc", "wpl", "xspf", "zpl"
    ]
    
    /// Sniffs a simple ZIP-based format, like Comic Book Archive or Zipped Audio Book.
    /// Reference: https://wiki.mobileread.com/wiki/CBR_and_CBZ
    private static func sniffZIP(context: FormatSnifferContext) -> Format? {
        if context.hasFileExtension("cbz") || context.hasMediaType("application/vnd.comicbook+zip", "application/x-cbz", "application/x-cbr") {
            return .CBZ
        }
        if context.hasFileExtension("zab") {
            return .ZAB
        }
        
        if context.contentAsZIP != nil {
            func isIgnored(_ url: URL) -> Bool {
                let filename = url.lastPathComponent
                return url.hasDirectoryPath || filename.hasPrefix(".") || filename == "Thumbs.db"
            }

            func zipContainsOnlyExtensions(_ fileExtensions: [String]) -> Bool {
                return context.zipEntriesAllSatisfy { url in
                    isIgnored(url) || fileExtensions.contains(url.pathExtension.lowercased())
                }
            }

            if zipContainsOnlyExtensions(cbzExtensions) {
                return .CBZ
            }
            if zipContainsOnlyExtensions(zabExtensions) {
                return .ZAB
            }
        }
        
        return nil
    }

    /// Sniffs a PDF document.
    /// Reference: https://www.loc.gov/preservation/digital/formats/fdd/fdd000123.shtml
    private static func sniffPDF(context: FormatSnifferContext) -> Format? {
        if context.hasFileExtension("pdf") || context.hasMediaType("application/pdf") {
            return .PDF
        }
        if context.readFileSignature(length: 5) == "%PDF-" {
            return .PDF
        }
        return nil
    }
    
    /// Sniffs a bitmap image.
    private static func sniffBitmap(context: FormatSnifferContext) -> Format? {
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
