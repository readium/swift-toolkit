//
//  MediaType.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 10/04/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// Represents a string media type.
///
/// `MediaType` handles:
/// * components parsing – eg. type, subtype and parameters,
/// * media types comparison.
///
/// Comparing media types is more complicated than it looks, since they can contain parameters,
/// such as `charset=utf-8`. We can't ignore them because some formats use parameters in their
/// media type, for example `application/atom+xml;profile=opds-catalog` for an OPDS 1 catalog.
///
/// Specification: https://tools.ietf.org/html/rfc6838
struct MediaType: Equatable {
    
    /// The type component, e.g. `application` in `application/epub+zip`.
    let type: String
    
    /// The subtype component, e.g. `epub+zip` in `application/epub+zip`.
    let subtype: String
    
    /// The parameters in the media type, such as `charset=utf-8`.
    let parameters: [String: String]
    
    /// The string representation of this media type.
    var string: String {
        let params = parameters.map { "\($0.key)=\($0.value)" }
            .sorted()
            .joined(separator: ";")
        return "\(type)/\(subtype)\(params.isEmpty ? "" : ";\(params)")"
    }

    init?(_ string: String) {
        // Grammar: https://tools.ietf.org/html/rfc2045#section-5.1
        let components = string.split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let types = components[0].split(separator: "/")
        guard types.count == 2 else {
            return nil
        }

        // > Both top-level type and subtype names are case-insensitive.
        self.type = types[0].lowercased()
        self.subtype = types[1].lowercased()
        
        // > Parameter names are case-insensitive and no meaning is attached to the order in which
        // > they appear.
        let parameterPairs: [(String, String)] = components[1...]
            .map { $0.split(separator: "=").map(String.init) }
            .filter { $0.count == 2 }
            .map { parts in (parts[0].lowercased(), parts[1]) }
        
        var parameters = Dictionary(uniqueKeysWithValues: parameterPairs)
        
        // For now, we only support case-insensitive `charset`.
        //
        // > Parameter values might or might not be case-sensitive, depending on the semantics of
        // > the parameter name.
        // > https://tools.ietf.org/html/rfc2616#section-3.7
        //
        // > The character set names may be up to 40 characters taken from the printable characters
        // > of US-ASCII.  However, no distinction is made between use of upper and lower case
        // > letters.
        // > https://www.iana.org/assignments/character-sets/character-sets.xhtml
        if let charset = parameters["charset"] {
            parameters["charset"] = charset.uppercased()
        }
        
        self.parameters = parameters
    }
    
    /// Returns whether the given `other` media type is included in this media type.
    ///
    /// For example, `text/html` contains `text/html;charset=utf-8`.
    ///
    /// * `other` must match the parameters in the `parameters` property, but extra parameters
    ///    are ignored.
    /// * Order of parameters is ignored.
    /// * Wildcards are supported, meaning that `image/*` contains `image/png` and `*/*` contains
    ///   everything.
    func contains(_ other: Self) -> Bool {
        guard type == "*" || type == other.type,
            subtype == "*" || subtype == other.subtype else
        {
            return false
        }
        
        let paramsSet = Set(parameters.map { "\($0.key)=\($0.value)" })
        let otherParamsSet = Set(other.parameters.map { "\($0.key)=\($0.value)" })
        return paramsSet.isSubset(of: otherParamsSet)
    }
    
    /// Returns whether the given `mediaType` is included in this media type.
    func contains(_ mediaType: String) -> Bool {
        guard let mediaType = Self(mediaType) else {
            return false
        }
        return contains(mediaType)
    }
    
    /// Returns whether this media type is of an OPDS feed.
    var isOPDS: Bool {
        return MediaType.OPDS1.contains(self)
            || MediaType.OPDS1Entry.contains(self)
            || MediaType.OPDS2.contains(self)
            || MediaType.OPDS2Publication.contains(self)
    }
    
    /// Returns whether this media type is of an HTML document.
    var isHTML: Bool {
        return MediaType.HTML.contains(self)
            || MediaType.XHTML.contains(self)
    }
    
    /// Returns whether this media type is of a bitmap image, so excluding vectorial formats.
    var isBitmap: Bool {
        return MediaType.BMP.contains(self)
            || MediaType.GIF.contains(self)
            || MediaType.JPEG.contains(self)
            || MediaType.PNG.contains(self)
            || MediaType.TIFF.contains(self)
            || MediaType.WebP.contains(self)
    }
    
    
    // MARK: Known Media Types
    
    static let AAC = MediaType("audio/aac")!
    static let ACSM = MediaType("application/vnd.adobe.adept+xml")!
    static let AIFF = MediaType("audio/aiff")!
    static let Audiobook = MediaType("application/audiobook+zip")!
    static let AudiobookManifest = MediaType("application/audiobook+json")!
    static let AVI = MediaType("video/x-msvideo")!
    static let Binary = MediaType("application/octet-stream")!
    static let BMP = MediaType("image/bmp")!
    static let CBZ = MediaType("application/vnd.comicbook+zip")!
    static let CSS = MediaType("text/css")!
    static let DiViNa = MediaType("application/divina+zip")!
    static let DiViNaManifest = MediaType("application/divina+json")!
    static let EPUB = MediaType("application/epub+zip")!
    static let GIF = MediaType("image/gif")!
    static let GZ = MediaType("application/gzip")!
    static let JavaScript = MediaType("text/javascript")!
    static let JPEG = MediaType("image/jpeg")!
    static let HTML = MediaType("text/html")!
    static let OPDS1 = MediaType("application/atom+xml;profile=opds-catalog")!
    static let OPDS1Entry = MediaType("application/atom+xml;type=entry;profile=opds-catalog")!
    static let OPDS2 = MediaType("application/opds+json")!
    static let OPDS2Publication = MediaType("application/opds-publication+json")!
    static let JSON = MediaType("application/json")!
    static let LCPProtectedAudiobook = MediaType("application/audiobook+lcp")!
    static let LCPProtectedPDF = MediaType("application/pdf+lcp")!
    static let LCPLicenseDocument = MediaType("application/vnd.readium.lcp.license.v1.0+json")!
    static let LCPStatusDocument = MediaType("application/vnd.readium.license.status.v1.0+json")!
    static let LPF = MediaType("application/lpf+zip")!
    static let MP3 = MediaType("audio/mpeg")!
    static let MPEG = MediaType("video/mpeg")!
    static let Ogg = MediaType("audio/ogg")!
    static let Ogv = MediaType("video/ogg")!
    static let Opus = MediaType("audio/opus")!
    static let OTF = MediaType("font/otf")!
    static let PDF = MediaType("application/pdf")!
    static let PNG = MediaType("image/png")!
    static let SVG = MediaType("image/svg+xml")!
    static let Text = MediaType("text/plain")!
    static let TIFF = MediaType("image/tiff")!
    static let TTF = MediaType("font/ttf")!
    static let W3CWPUBManifest = MediaType("application/x.readium.w3c.wpub+json")!  // non-existent
    static let WAV = MediaType("audio/wav")!
    static let WebMAudio = MediaType("audio/webm")!
    static let WebMVideo = MediaType("video/webm")!
    static let WebP = MediaType("image/webp")!
    static let WebPub = MediaType("application/webpub+zip")!
    static let WebPubManifest = MediaType("application/webpub+json")!
    static let WOFF = MediaType("font/woff")!
    static let WOFF2 = MediaType("font/woff2")!
    static let XHTML = MediaType("application/xhtml+xml")!
    static let XML = MediaType("application/xml")!
    static let ZAB = MediaType("application/x.readium.zab+zip")!  // non-existent
    static let ZIP = MediaType("application/zip")!

}
