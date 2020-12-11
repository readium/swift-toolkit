//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import CoreServices
import Foundation
import Fuzi

public extension MediaType {
    
    /// Determines if the provided content matches a known media type.
    ///
    /// - Parameter context: Holds the file metadata and cached content, which are shared among the
    ///   sniffers.
    typealias Sniffer = (_ context: MediaTypeSnifferContext) -> MediaType?

    /// resolves a media type from a single file extension and media type hint, without checking the
    /// actual content.
    static func of(mediaType: String? = nil, fileExtension: String? = nil, sniffers: [Sniffer] = sniffers) -> MediaType? {
        return of(content: nil, mediaTypes: Array(ofNotNil: mediaType), fileExtensions: Array(ofNotNil: fileExtension), sniffers: sniffers)
    }

    /// Resolves a media type from file extension and media type hints, without checking the actual
    /// content.
    static func of(mediaTypes: [String], fileExtensions: [String], sniffers: [Sniffer] = sniffers) -> MediaType? {
        return of(content: nil, mediaTypes: mediaTypes, fileExtensions: fileExtensions, sniffers: sniffers)
    }
    
    /// Resolves a media type from a local file path.
    /// **Warning**: This API should never be called from the UI thread.
    static func of(_ file: URL, mediaType: String? = nil, fileExtension: String? = nil, sniffers: [Sniffer] = sniffers) -> MediaType? {
        return of(file, mediaTypes: Array(ofNotNil: mediaType), fileExtensions: Array(ofNotNil: fileExtension), sniffers: sniffers)
    }
    
    /// Resolves a media type from a local file path.
    /// **Warning**: This API should never be called from the UI thread.
    static func of(_ file: URL, mediaTypes: [String], fileExtensions: [String], sniffers: [Sniffer] = sniffers) -> MediaType? {
        let fileExtensions = [file.pathExtension] + fileExtensions
        return of(content: FileMediaTypeSnifferContent(file: file), mediaTypes: mediaTypes, fileExtensions: fileExtensions, sniffers: sniffers)
    }
    
    /// Resolves a media type from bytes, e.g. from an HTTP response.
    /// **Warning**: This API should never be called from the UI thread.
    static func of(_ data: @escaping () -> Data, mediaType: String? = nil, fileExtension: String? = nil, sniffers: [Sniffer] = sniffers) -> MediaType? {
        return of(data, mediaTypes: Array(ofNotNil: mediaType), fileExtensions: Array(ofNotNil: fileExtension), sniffers: sniffers)
    }
    
    /// Resolves a media type from bytes, e.g. from an HTTP response.
    /// **Warning**: This API should never be called from the UI thread.
    static func of(_ data: @escaping () -> Data, mediaTypes: [String], fileExtensions: [String], sniffers: [Sniffer] = sniffers) -> MediaType? {
        return of(content: DataMediaTypeSnifferContent(data: data), mediaTypes: mediaTypes, fileExtensions: fileExtensions, sniffers: sniffers)
    }
    
    /// Resolves a media type from a sniffer context.
    ///
    /// Sniffing a media type is done in two rounds, because we want to give an opportunity to all
    /// sniffers to return a `MediaType` quickly before inspecting the content itself:
    /// * *Light Sniffing* checks only the provided file extension or media type hints.
    /// * *Heavy Sniffing* reads the bytes to perform more advanced sniffing.
    private static func of(content: MediaTypeSnifferContent?, mediaTypes: [String], fileExtensions: [String], sniffers: [Sniffer]) -> MediaType? {
        if content != nil {
            warnIfMainThread()
        }
        
        // Light sniffing
        let context = MediaTypeSnifferContext(mediaTypes: mediaTypes, fileExtensions: fileExtensions)
        for sniffer in sniffers {
            if let mediaType = sniffer(context) {
                return mediaType
            }
        }
        
        // Heavy sniffing
        if let content = content {
            let context = MediaTypeSnifferContext(content: content, mediaTypes: mediaTypes, fileExtensions: fileExtensions)
            for sniffer in sniffers {
                if let mediaType = sniffer(context) {
                    return mediaType
                }
            }
        }
        
        // Falls back on either:
        //
        // - the Document Types registered in the reading app
        // - system-wide UTIs
        // - the first valid media type hint provided
        //
        // Note: This is done after the heavy sniffing of the provided `sniffers`, because otherwise
        // the Document Types or system UTI will detect JSON, XML or ZIP media types before we have a
        // chance of sniffing their content (for example, for RWPM).
        return sniffDocumentTypes(context)
            ?? sniffUTIs(context)
            ?? mediaTypes.first { MediaType($0) }
    }

    
    // MARK: Sniffers
    
    /// The default sniffers provided by Readium 2 to resolve a `MediaType`.
    ///
    /// You can register additional sniffers globally by modifying this list.
    /// The sniffers order is important, because some media types are subsets of other media types.
    static var sniffers: [Sniffer] = [
        sniffHTML, sniffOPDS, sniffLCPLicense, sniffBitmap,
        sniffWebPub, sniffW3CWPUB, sniffEPUB, sniffLPF, sniffArchive, sniffPDF
    ]

    /// Sniffs an HTML document.
    private static func sniffHTML(context: MediaTypeSnifferContext) -> MediaType? {
        if context.hasFileExtension("htm", "html", "xht", "xhtml") || context.hasMediaType("text/html", "application/xhtml+xml") {
            return .html
        }
        if context.contentAsXML?.documentElement?.localName.lowercased() == "html" {
            return .html
        }
        return nil
    }

    /// Sniffs an OPDS document.
    private static func sniffOPDS(context: MediaTypeSnifferContext) -> MediaType? {
        // OPDS 1
        if context.hasMediaType("application/atom+xml;type=entry;profile=opds-catalog") {
            return .opds1Entry
        }
        if context.hasMediaType("application/atom+xml;profile=opds-catalog") {
            return .opds1
        }
        if let xml = context.contentAsXML {
            let namespaces = [(prefix: "atom", uri: "http://www.w3.org/2005/Atom")]
            if xml.first("/atom:feed", with: namespaces) != nil {
                return .opds1
            } else if xml.first("/atom:entry", with: namespaces) != nil {
                return .opds1Entry
            }
        }
        
        // OPDS 2
        if context.hasMediaType("application/opds+json") {
            return .opds2
        }
        if context.hasMediaType("application/opds-publication+json") {
            return .opds2Publication
        }
        if let rwpm = context.contentAsRWPM {
            if rwpm.link(withRel: .`self`)?.type == "application/opds+json" {
                return .opds2
            }
            if rwpm.link(withRelMatching: { $0.hasPrefix("http://opds-spec.org/acquisition") }) != nil {
                return .opds2Publication
            }
        }
        
        // OPDS Authentication Document.
        if context.hasMediaType("application/opds-authentication+json") || context.hasMediaType("application/vnd.opds.authentication.v1.0+json") {
            return .opdsAuthentication
        }
        if let json = context.contentAsJSON as? [String: Any] {
            if Set(json.keys).isSuperset(of: ["id", "title", "authentication"]) {
                return .opdsAuthentication
            }
        }

        return nil
    }
    
    /// Sniffs an LCP License Document.
    private static func sniffLCPLicense(context: MediaTypeSnifferContext) -> MediaType? {
        if context.hasFileExtension("lcpl") || context.hasMediaType("application/vnd.readium.lcp.license.v1.0+json") {
            return .lcpLicenseDocument
        }
        if let json = context.contentAsJSON as? [String: Any] {
            if Set(json.keys).isSuperset(of: ["id", "issued", "provider", "encryption"]) {
                return .lcpLicenseDocument
            }
        }
        return nil
    }
    
    /// Sniffs a Readium Web Publication, protected or not by LCP.
    private static func sniffWebPub(context: MediaTypeSnifferContext) -> MediaType? {
        if context.hasFileExtension("audiobook") || context.hasMediaType("application/audiobook+zip") {
            return .readiumAudiobook
        }
        if context.hasMediaType("application/audiobook+json") {
            return .readiumAudiobookManifest
        }
        
        if context.hasFileExtension("divina") || context.hasMediaType("application/divina+zip") {
            return .divina
        }
        if context.hasMediaType("application/divina+json") {
            return .divinaManifest
        }
        
        if context.hasFileExtension("webpub") || context.hasMediaType("application/webpub+zip") {
            return .readiumWebPub
        }
        if context.hasMediaType("application/webpub+json") {
            return .readiumWebPubManifest
        }
        
        if context.hasFileExtension("lcpa") || context.hasMediaType("application/audiobook+lcp") {
            return .lcpProtectedAudiobook
        }
        if context.hasFileExtension("lcpdf") || context.hasMediaType("application/pdf+lcp") {
            return .lcpProtectedPDF
        }
        
        /// Reads a RWPM, either from a manifest.json file, or from a manifest.json Archive entry,
        /// if the file is an archive.
        func readRWPM() -> (isManifest: Bool, Manifest)? {
            if let rwpm = context.contentAsRWPM {
                return (isManifest: true, rwpm)
            } else if let manifestData = context.readArchiveEntry(at: "manifest.json"),
                let manifestJSON = try? JSONSerialization.jsonObject(with: manifestData),
                let rwpm = try? Manifest(json: manifestJSON) {
                return (isManifest: false, rwpm)
            } else {
                return nil
            }
        }

        if let (isManifest, rwpm) = readRWPM() {
            let isLCPProtected = context.containsArchiveEntry(at: "license.lcpl")

            if rwpm.metadata.type == "http://schema.org/Audiobook" || rwpm.readingOrder.allAreAudio {
                return isManifest ? .readiumAudiobookManifest :
                    isLCPProtected ? .lcpProtectedAudiobook : .readiumAudiobook
            }
            if rwpm.readingOrder.allAreBitmap {
                return isManifest ? .divinaManifest : .divina
            }
            if isLCPProtected, rwpm.readingOrder.all(matchMediaType: .pdf) {
                return .lcpProtectedPDF
            }
            if rwpm.link(withRel: .`self`)?.type == "application/webpub+json" {
                return isManifest ? .readiumWebPubManifest : .readiumWebPub
            }
        }

        return nil
    }
    
    /// Sniffs a W3C Web Publication Manifest.
    private static func sniffW3CWPUB(context: MediaTypeSnifferContext) -> MediaType? {
        if let json = context.contentAsJSON as? [String: Any],
            let context = json["@context"] as? [Any],
            context.contains(where: { ($0 as? String) == "https://www.w3.org/ns/wp-context" })
        {
            return .w3cWPUBManifest
        }
        return nil
    }

    /// Sniffs an EPUB publication.
    /// Reference: https://www.w3.org/publishing/epub3/epub-ocf.html#sec-zip-container-mime
    private static func sniffEPUB(context: MediaTypeSnifferContext) -> MediaType? {
        if context.hasFileExtension("epub") || context.hasMediaType("application/epub+zip") {
            return .epub
        }
        if let mimetypeData = context.readArchiveEntry(at: "mimetype"),
            let mimetype = String(data: mimetypeData, encoding: .ascii)?.trimmingCharacters(in: .whitespacesAndNewlines),
            mimetype == "application/epub+zip"
        {
            return .epub
        }
        return nil
    }
    
    /// Sniffs a Lightweight Packaging Format (LPF).
    /// References:
    /// * https://www.w3.org/TR/lpf/
    /// * https://www.w3.org/TR/pub-manifest/
    private static func sniffLPF(context: MediaTypeSnifferContext) -> MediaType? {
        if context.hasFileExtension("lpf") || context.hasMediaType("application/lpf+zip") {
            return .lpf
        }
        if context.containsArchiveEntry(at: "index.html") {
            return .lpf
        }
        if let data = context.readArchiveEntry(at: "publication.json"),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let contexts = json["@context"] as? [Any],
            contexts.contains(where: {($0 as? String) == "https://www.w3.org/ns/pub-context"})
        {
            return .lpf
        }
        return nil
    }

    /// Authorized extensions for resources in a CBZ archive.
    /// Reference: https://wiki.mobileread.com/wiki/CBR_and_CBZ
    private static let cbzExtensions = [
        // bitmap
        "bmp", "dib", "gif", "jif", "jfi", "jfif", "jpg", "jpeg", "png", "tif", "tiff", "webp",
        // metadata
        "acbf", "xml"
    ]
    
    /// Authorized extensions for resources in a ZAB archive (Zipped Audio Book).
    private static let zabExtensions = [
        // audio
        "aac", "aiff", "alac", "flac", "m4a", "m4b", "mp3", "ogg", "oga", "mogg", "opus", "wav", "webm",
        // playlist
        "asx", "bio", "m3u", "m3u8", "pla", "pls", "smil", "vlc", "wpl", "xspf", "zpl"
    ]
    
    /// Sniffs a simple archive-based format, like Comic Book Archive or Zipped Audio Book.
    /// Reference: https://wiki.mobileread.com/wiki/CBR_and_CBZ
    private static func sniffArchive(context: MediaTypeSnifferContext) -> MediaType? {
        if context.hasFileExtension("cbz") || context.hasMediaType("application/vnd.comicbook+zip", "application/x-cbz", "application/x-cbr") {
            return .cbz
        }
        if context.hasFileExtension("zab") {
            return .zab
        }
        
        if context.contentAsArchive != nil {
            func isIgnored(_ url: URL) -> Bool {
                let filename = url.lastPathComponent
                return url.hasDirectoryPath || filename.hasPrefix(".") || filename == "Thumbs.db"
            }

            func archiveContainsOnlyExtensions(_ fileExtensions: [String]) -> Bool {
                return context.archiveEntriesAllSatisfy { url in
                    isIgnored(url) || fileExtensions.contains(url.pathExtension.lowercased())
                }
            }

            if archiveContainsOnlyExtensions(cbzExtensions) {
                return .cbz
            }
            if archiveContainsOnlyExtensions(zabExtensions) {
                return .zab
            }
        }
        
        return nil
    }

    /// Sniffs a PDF document.
    /// Reference: https://www.loc.gov/preservation/digital/formats/fdd/fdd000123.shtml
    private static func sniffPDF(context: MediaTypeSnifferContext) -> MediaType? {
        if context.hasFileExtension("pdf") || context.hasMediaType("application/pdf") {
            return .pdf
        }
        if context.read(length: 5).flatMap({ String(data: $0, encoding: .utf8) }) == "%PDF-" {
            return .pdf
        }
        return nil
    }
    
    /// Sniffs a bitmap image.
    private static func sniffBitmap(context: MediaTypeSnifferContext) -> MediaType? {
        if context.hasFileExtension("bmp", "dib") || context.hasMediaType("image/bmp", "image/x-bmp") {
            return .bmp
        }
        if context.hasFileExtension("gif") || context.hasMediaType("image/gif") {
            return .gif
        }
        if context.hasFileExtension("jpg", "jpeg", "jpe", "jif", "jfif", "jfi") || context.hasMediaType("image/jpeg") {
            return .jpeg
        }
        if context.hasFileExtension("png") || context.hasMediaType("image/png") {
            return .png
        }
        if context.hasFileExtension("tiff", "tif") || context.hasMediaType("image/tiff", "image/tiff-fx") {
            return .tiff
        }
        if context.hasFileExtension("webp") || context.hasMediaType("image/webp") {
            return .webp
        }
        return nil
    }
    
    /// Sniffs the media types declared in the Document Types section of the app's `Info.plist`.
    private static func sniffDocumentTypes(_ context: MediaTypeSnifferContext) -> MediaType? {
        func sniff(_ documentType: DocumentType) -> MediaType? {
            guard let mediaType = documentType.preferredMediaType else {
                return nil
            }
            
            for mediaType in documentType.mediaTypes {
                if context.hasMediaType(mediaType.string) {
                    return mediaType
                }
            }
            
            for fileExtension in documentType.fileExtensions {
                if context.hasFileExtension(fileExtension) {
                    return mediaType
                }
            }
            
            return nil
        }

        for type in DocumentTypes.main.all {
            if let mediaType = sniff(type) {
                return mediaType
            }
        }
        
        return nil
    }
    
    /// Sniffs the Uniform Type Identifiers registered on the system.
    private static func sniffUTIs(_ context: MediaTypeSnifferContext) -> MediaType? {
        guard let uti = UTI.findFrom(mediaTypes: context.mediaTypes, fileExtensions: context.fileExtensions),
            let name = uti.name,
            let mediaType = uti.preferredTag(withClass: .mediaType),
            let fileExtension = uti.preferredTag(withClass: .fileExtension) else
        {
            return nil
        }
        
        return MediaType(mediaType, name: name, fileExtension: fileExtension)
    }

}

public extension URLResponse {
    
    /// Sniffs the media type for this `URLResponse`, using the default media type sniffers.
    var mediaType: MediaType? {
        sniffMediaType()
    }

    /// Resolves the media type for this `URLResponse`, with optional extra file extension and media
    /// type hints.
    func sniffMediaType(data: (() -> Data)? = nil, mediaTypes: [String] = [], fileExtensions: [String] = [], sniffers: [MediaType.Sniffer] = MediaType.sniffers) -> MediaType? {
        var mediaTypes = mediaTypes
        // The value of the `Content-Type` HTTP header.
        if let mimeType = mimeType {
            mediaTypes.insert(mimeType, at: 0)
        }
        
        var fileExtensions = fileExtensions
        // The URL file extension.
        if let urlExtension = url?.pathExtension {
            fileExtensions.insert(urlExtension, at: 0)
        }
        // The suggested filename extension, part of the HTTP header `Content-Disposition`.
        if let suggestedFileExtension = suggestedFilename.map(URL.init(fileURLWithPath:))?.pathExtension {
            fileExtensions.insert(suggestedFileExtension, at: 0)
        }
        
        if let data = data {
            return MediaType.of({ data() }, mediaTypes: mediaTypes, fileExtensions: fileExtensions, sniffers: sniffers)
        } else {
            return MediaType.of(mediaTypes: mediaTypes, fileExtensions: fileExtensions, sniffers: sniffers)
        }
    }

}

private extension Manifest {

    /// Finds the first `Link` having the given `rel` matching the given `predicate`, in the
    /// publications' links.
    func link(withRelMatching predicate: (LinkRelation) -> Bool) -> Link? {
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
