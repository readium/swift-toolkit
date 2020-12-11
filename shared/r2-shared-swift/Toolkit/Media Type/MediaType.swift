//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Represents a document format, identified by a unique RFC 6838 media type.
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
///
/// You can register new media types in an extension, for example:
///
/// ```
/// extension MediaType {
///     var doc: MediaType {
///         MediaType("application/msword", name: "Word Document", fileExtension: "doc")!
///     }
/// }
/// ```
public struct MediaType: Hashable, Loggable {
    
    /// The string representation of this media type.
    public var string: String {
        let params = parameters
            .map { "\($0.key)=\($0.value)" }
            .sorted()
            .joined(separator: ";")
        return "\(type)/\(subtype)\(params.isEmpty ? "" : ";\(params)")"
    }
    
    /// A human readable name identifying the media type, which may be presented to the user.
    public let name: String?
    
    /// The default file extension to use for this media type.
    public let fileExtension: String?
    
    /// The type component, e.g. `application` in `application/epub+zip`.
    public let type: String
    
    /// The subtype component, e.g. `epub+zip` in `application/epub+zip`.
    public let subtype: String
    
    /// The parameters in the media type, such as `charset=utf-8`.
    public let parameters: [String: String]
    
    /// Structured syntax suffix, e.g. `+zip` in `application/epub+zip`
    ///
    /// Gives a hint on the underlying structure of this media type.
    /// See. https://tools.ietf.org/html/rfc6838#section-4.2.8
    public var structuredSyntaxSuffix: String? {
        let parts = subtype.split(separator: "+", omittingEmptySubsequences: true)
        return (parts.count > 1)
            ? "+\(parts.last!)"
            : nil
    }
    
    /// Encoding as declared in the `charset` parameter, if there's any.
    public var encoding: String.Encoding? {
        parameters["charset"].flatMap { String.Encoding(charset: $0) }
    }

    /// Returns the canonical version of this media type, if it is known.
    ///
    /// This is useful to find the name and file extension of a known media type, or to get the canonical media type
    /// from an alias. For example, `application/x-cbz` is an alias of the canonical `application/vnd.comicbook+zip`.
    ///
    /// Non-significant parameters are also discarded.
    public var canonicalized: MediaType {
        MediaType.of(mediaType: string) ?? self
    }

    public init?(_ string: String, name: String? = nil, fileExtension: String? = nil) {
        guard !string.isEmpty else {
            return nil
        }
    
        self.name = name
        self.fileExtension = fileExtension
    
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
    
    /// Returns whether this media type and `other` are the same, ignoring parameters that are not
    /// in both media types.
    ///
    /// For example, `text/html` matches `text/html;charset=utf-8`, but `text/html;charset=ascii`
    /// doesn't. This is basically like `contains`, but working in both direction.
    public func matches(_ other: Self?) -> Bool {
        return contains(other) || (other?.contains(self) ?? false)
    }
    
    /// Returns whether this media type and `other` are the same, ignoring parameters that are not
    /// in both media types.
    public func matches(_ other: String?) -> Bool {
        return matches(other.flatMap { MediaType($0) })
    }
    
    /// Returns whether this media type matches any of the `others` media types.
    public func matchesAny(_ other: Self...) -> Bool {
        return other.contains { matches($0) }
    }
    
    /// Returns whether this media type matches any of the `others` media types.
    public func matchesAny(_ other: String...) -> Bool {
        return other.contains { matches($0) }
    }
    
    /// Returns whether this media type matches any of the `others` media types.
    public func matchesAny(_ others: [Self]) -> Bool {
        return others.contains { matches($0) }
    }
    
    /// Returns whether this media type matches any of the `others` media types.
    public func matchesAny(_ others: [String]) -> Bool {
        return others.contains { matches($0) }
    }

    /// Returns whether this media type is structured as a ZIP archive.
    public var isZIP: Bool {
        matchesAny(.zip, .lcpProtectedAudiobook, .lcpProtectedPDF) || structuredSyntaxSuffix == "+zip"
    }
    
    /// Returns whether this media type is structured as a JSON file.
    public var isJSON: Bool {
        matches(.json) || structuredSyntaxSuffix == "+json"
    }

    /// Returns whether this media type is of an OPDS feed.
    public var isOPDS: Bool {
        matchesAny(.opds1, .opds1Entry, .opds2, .opds2Publication, .opdsAuthentication)
    }
    
    /// Returns whether this media type is of an HTML document.
    public var isHTML: Bool {
        matchesAny(.html, .xhtml)
    }
    
    /// Returns whether this media type is of a bitmap image, so excluding vectorial formats.
    public var isBitmap: Bool {
        matchesAny(.bmp, .gif, .jpeg, .png, .tiff, .webp)
    }
    
    /// Returns whether this media type is of an audio clip.
    public var isAudio: Bool {
        type == "audio"
    }
    
    /// Returns whether this media type is of a video clip.
    public var isVideo: Bool {
        return type == "video"
    }
    
    /// Returns whether this media type is of a Readium Web Publication Manifest.
    public var isRWPM: Bool {
        matchesAny(.readiumWebPubManifest, .readiumAudiobookManifest, .divinaManifest)
    }

    /// Returns whether this media type is declared in the Document Types section of the app's main
    /// bundle.
    public var isSupportedDocumentType: Bool {
        return DocumentTypes.main.supportsMediaType(string)
            || DocumentTypes.main.supportsFileExtension(fileExtension)
    }

    
    // MARK: Known Media Types
    
    public static let aac = MediaType("audio/aac", fileExtension: "aac")!
    public static let acsm = MediaType("application/vnd.adobe.adept+xml", name: "Adobe Content Server Message", fileExtension: "acsm")!
    public static let aiff = MediaType("audio/aiff", fileExtension: "aiff")!
    public static let avi = MediaType("video/x-msvideo", fileExtension: "avi")!
    public static let binary = MediaType("application/octet-stream")!
    public static let bmp = MediaType("image/bmp", fileExtension: "bmp")!
    public static let cbz = MediaType("application/vnd.comicbook+zip", name: "Comic Book Archive", fileExtension: "cbz")!
    public static let css = MediaType("text/css", fileExtension: "css")!
    public static let divina = MediaType("application/divina+zip", name: "Digital Visual Narratives", fileExtension: "divina")!
    public static let divinaManifest = MediaType("application/divina+json", name: "Digital Visual Narratives", fileExtension: "json")!
    public static let epub = MediaType("application/epub+zip", name: "EPUB", fileExtension: "epub")!
    public static let gif = MediaType("image/gif", fileExtension: "gif")!
    public static let gz = MediaType("application/gzip", fileExtension: "gz")!
    public static let html = MediaType("text/html", fileExtension: "html")!
    public static let javascript = MediaType("text/javascript", fileExtension: "js")!
    public static let jpeg = MediaType("image/jpeg", fileExtension: "jpg")!
    public static let json = MediaType("application/json", fileExtension: "json")!
    public static let lcpLicenseDocument = MediaType("application/vnd.readium.lcp.license.v1.0+json", name: "LCP License", fileExtension: "lcpl")!
    public static let lcpProtectedAudiobook = MediaType("application/audiobook+lcp", name: "LCP Protected Audiobook", fileExtension: "lcpa")!
    public static let lcpProtectedPDF = MediaType("application/pdf+lcp", name: "LCP Protected PDF", fileExtension: "lcpdf")!
    public static let lcpStatusDocument = MediaType("application/vnd.readium.license.status.v1.0+json")!
    public static let lpf = MediaType("application/lpf+zip", fileExtension: "lpf")!
    public static let mp3 = MediaType("audio/mpeg", fileExtension: "mp3")!
    public static let mpeg = MediaType("video/mpeg", fileExtension: "mpeg")!
    public static let ncx = MediaType("application/x-dtbncx+xml", fileExtension: "ncx")!
    public static let ogg = MediaType("audio/ogg", fileExtension: "oga")!
    public static let ogv = MediaType("video/ogg", fileExtension: "ogv")!
    public static let opds1 = MediaType("application/atom+xml;profile=opds-catalog")!
    public static let opds1Entry = MediaType("application/atom+xml;type=entry;profile=opds-catalog")!
    public static let opds2 = MediaType("application/opds+json")!
    public static let opds2Publication = MediaType("application/opds-publication+json")!
    public static let opdsAuthentication = MediaType("application/opds-authentication+json")!
    public static let opus = MediaType("audio/opus", fileExtension: "opus")!
    public static let otf = MediaType("font/otf", fileExtension: "otf")!
    public static let pdf = MediaType("application/pdf", name: "PDF", fileExtension: "pdf")!
    public static let png = MediaType("image/png", fileExtension: "png")!
    public static let readiumAudiobook = MediaType("application/audiobook+zip", name: "Readium Audiobook", fileExtension: "audiobook")!
    public static let readiumAudiobookManifest = MediaType("application/audiobook+json", name: "Readium Audiobook", fileExtension: "json")!
    public static let readiumWebPub = MediaType("application/webpub+zip", name: "Readium Web Publication", fileExtension: "webpub")!
    public static let readiumWebPubManifest = MediaType("application/webpub+json", name: "Readium Web Publication", fileExtension: "json")!
    public static let smil = MediaType("application/smil+xml", fileExtension: "smil")!
    public static let svg = MediaType("image/svg+xml", fileExtension: "svg")!
    public static let text = MediaType("text/plain", fileExtension: "txt")!
    public static let tiff = MediaType("image/tiff", fileExtension: "tiff")!
    public static let ttf = MediaType("font/ttf", fileExtension: "ttf")!
    public static let w3cWPUBManifest = MediaType("application/x.readium.w3c.wpub+json", name: "Web Publication", fileExtension: "json")!  // non-existent
    public static let wav = MediaType("audio/wav", fileExtension: "wav")!
    public static let webmAudio = MediaType("audio/webm", fileExtension: "webm")!
    public static let webmVideo = MediaType("video/webm", fileExtension: "webm")!
    public static let webp = MediaType("image/webp", fileExtension: "webp")!
    public static let woff = MediaType("font/woff", fileExtension: "woff")!
    public static let woff2 = MediaType("font/woff2", fileExtension: "woff2")!
    public static let xhtml = MediaType("application/xhtml+xml", fileExtension: "xhtml")!
    public static let xml = MediaType("application/xml", fileExtension: "xml")!
    public static let zab = MediaType("application/x.readium.zab+zip", name: "Zipped Audio Book", fileExtension: "zab")!  // non-existent
    public static let zip = MediaType("application/zip", fileExtension: "zip")!
    
    static let readiumPositions = MediaType("application/vnd.readium.position-list+json")!
    static let readiumContentProtection = MediaType("application/vnd.readium.content-protection+json")!
    static let readiumRightsCopy = MediaType("application/vnd.readium.rights.copy+json")!
    static let readiumRightsPrint = MediaType("application/vnd.readium.rights.print+json")!

    /// `text/html` != `text/html;charset=utf-8` with strict equality comparison, which is most
    /// likely not the desired result. Instead, you can use `matches()` to check if any of the media
    /// types is a parameterized version of the other one.
    ///
    /// To ignore this warning, compare `MediaType.string` instead of `MediaType` itself.
    @available(*, deprecated, message: "Strict media type comparisons can be a source of bug, if parameters are present", renamed: "matches()")
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.string == rhs.string
    }

    public static func ~= (pattern: MediaType, value: MediaType) -> Bool {
        return pattern.matches(value)
    }

}


public extension Link {
    
    /// Media type of the linked resource.
    var mediaType: MediaType {
        type.flatMap { MediaType.of(mediaType: $0, fileExtension: URL(string: href)?.pathExtension) }
            ?? .binary
    }

}
