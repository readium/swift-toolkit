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
public struct MediaType: Equatable, Hashable {
    
    /// The type component, e.g. `application` in `application/epub+zip`.
    public let type: String
    
    /// The subtype component, e.g. `epub+zip` in `application/epub+zip`.
    public let subtype: String
    
    /// The parameters in the media type, such as `charset=utf-8`.
    public let parameters: [String: String]
    
    /// The string representation of this media type.
    public var string: String {
        let params = parameters.map { "\($0.key)=\($0.value)" }
            .sorted()
            .joined(separator: ";")
        return "\(type)/\(subtype)\(params.isEmpty ? "" : ";\(params)")"
    }
    
    /// Encoding as declared in the `charset` parameter, if there's any.
    public var encoding: String.Encoding? {
        parameters["charset"].flatMap { String.Encoding(charset: $0) }
    }

    public init?(_ string: String) {
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
    public func contains(_ other: Self?) -> Bool {
        guard let other = other,
            type == "*" || type == other.type,
            subtype == "*" || subtype == other.subtype else
        {
            return false
        }
        
        let paramsSet = Set(parameters.map { "\($0.key)=\($0.value)" })
        let otherParamsSet = Set(other.parameters.map { "\($0.key)=\($0.value)" })
        return paramsSet.isSubset(of: otherParamsSet)
    }
    
    /// Returns whether the given `mediaType` is included in this media type.
    public func contains(_ other: String?) -> Bool {
        guard let other = other.map({ Self($0) }) else {
            return false
        }
        return contains(other)
    }
    
    /// Returns whether this media type is included in the provided `other` media type.
    ///
    /// For example, `text/html;charset=utf-8` is part of `text/html`.
    public func isPartOf(_ other: Self?) -> Bool {
        return other?.contains(self) ?? false
    }
    
    /// Returns whether this media type is included in the provided `other` media type.
    public func isPartOf(_ other: String?) -> Bool {
        return other.flatMap(MediaType.init)?.contains(self) ?? false
    }

    /// Returns whether this media type is of an OPDS feed.
    public var isOPDS: Bool {
        return isPartOf(.OPDS1)
            || isPartOf(.OPDS1Entry)
            || isPartOf(.OPDS2)
            || isPartOf(.OPDS2Publication)
    }
    
    /// Returns whether this media type is of an HTML document.
    public var isHTML: Bool {
        return isPartOf(.HTML)
            || isPartOf(.XHTML)
    }
    
    /// Returns whether this media type is of a bitmap image, so excluding vectorial formats.
    public var isBitmap: Bool {
        return isPartOf(.BMP)
            || isPartOf(.GIF)
            || isPartOf(.JPEG)
            || isPartOf(.PNG)
            || isPartOf(.TIFF)
            || isPartOf(.WebP)
    }
    
    /// Returns whether this media type is of a Readium Web Publication Manifest.
    public var isRWPM: Bool {
        return isPartOf(.AudiobookManifest)
            || isPartOf(.DiViNaManifest)
            || isPartOf(.WebPubManifest)
    }

    
    // MARK: Known Media Types
    
    public static let AAC = MediaType("audio/aac")!
    public static let ACSM = MediaType("application/vnd.adobe.adept+xml")!
    public static let AIFF = MediaType("audio/aiff")!
    public static let Audiobook = MediaType("application/audiobook+zip")!
    public static let AudiobookManifest = MediaType("application/audiobook+json")!
    public static let AVI = MediaType("video/x-msvideo")!
    public static let Binary = MediaType("application/octet-stream")!
    public static let BMP = MediaType("image/bmp")!
    public static let CBZ = MediaType("application/vnd.comicbook+zip")!
    public static let CSS = MediaType("text/css")!
    public static let DiViNa = MediaType("application/divina+zip")!
    public static let DiViNaManifest = MediaType("application/divina+json")!
    public static let EPUB = MediaType("application/epub+zip")!
    public static let GIF = MediaType("image/gif")!
    public static let GZ = MediaType("application/gzip")!
    public static let JavaScript = MediaType("text/javascript")!
    public static let JPEG = MediaType("image/jpeg")!
    public static let HTML = MediaType("text/html")!
    public static let OPDS1 = MediaType("application/atom+xml;profile=opds-catalog")!
    public static let OPDS1Entry = MediaType("application/atom+xml;type=entry;profile=opds-catalog")!
    public static let OPDS2 = MediaType("application/opds+json")!
    public static let OPDS2Publication = MediaType("application/opds-publication+json")!
    public static let JSON = MediaType("application/json")!
    public static let LCPProtectedAudiobook = MediaType("application/audiobook+lcp")!
    public static let LCPProtectedPDF = MediaType("application/pdf+lcp")!
    public static let LCPLicenseDocument = MediaType("application/vnd.readium.lcp.license.v1.0+json")!
    public static let LCPStatusDocument = MediaType("application/vnd.readium.license.status.v1.0+json")!
    public static let LPF = MediaType("application/lpf+zip")!
    public static let MP3 = MediaType("audio/mpeg")!
    public static let MPEG = MediaType("video/mpeg")!
    public static let NCX = MediaType("application/x-dtbncx+xml")!
    public static let Ogg = MediaType("audio/ogg")!
    public static let Ogv = MediaType("video/ogg")!
    public static let Opus = MediaType("audio/opus")!
    public static let OTF = MediaType("font/otf")!
    public static let PDF = MediaType("application/pdf")!
    public static let PNG = MediaType("image/png")!
    public static let SMIL = MediaType("application/smil+xml")!
    public static let SVG = MediaType("image/svg+xml")!
    public static let Text = MediaType("text/plain")!
    public static let TIFF = MediaType("image/tiff")!
    public static let TTF = MediaType("font/ttf")!
    public static let W3CWPUBManifest = MediaType("application/x.readium.w3c.wpub+json")!  // non-existent
    public static let WAV = MediaType("audio/wav")!
    public static let WebMAudio = MediaType("audio/webm")!
    public static let WebMVideo = MediaType("video/webm")!
    public static let WebP = MediaType("image/webp")!
    public static let WebPub = MediaType("application/webpub+zip")!
    public static let WebPubManifest = MediaType("application/webpub+json")!
    public static let WOFF = MediaType("font/woff")!
    public static let WOFF2 = MediaType("font/woff2")!
    public static let XHTML = MediaType("application/xhtml+xml")!
    public static let XML = MediaType("application/xml")!
    public static let ZAB = MediaType("application/x.readium.zab+zip")!  // non-existent
    public static let ZIP = MediaType("application/zip")!

    public static func ~= (pattern: MediaType, value: MediaType) -> Bool {
        return pattern.contains(value)
    }

}


public extension Link {
    
    /// Media type of the linked resource.
    var mediaType: MediaType? {
        type.flatMap { MediaType($0) }
    }

}
