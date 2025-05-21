//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// Represents and holds information about the document format of an asset.
public struct Format: Hashable {
    public var specifications: FormatSpecifications
    public var mediaType: MediaType?
    public var fileExtension: FileExtension?

    /// Returns the UTI (Uniform Type Identifier) matching this format, if any.
    public var uti: String? {
        UTI.findFrom(mediaTypes: Array(ofNotNil: mediaType?.string), fileExtensions: Array(ofNotNil: fileExtension?.rawValue))?.string
    }

    public init(
        specifications: FormatSpecification...,
        mediaType: MediaType? = nil,
        fileExtension: FileExtension? = nil
    ) {
        self.init(
            specifications: Set(specifications),
            mediaType: mediaType,
            fileExtension: fileExtension
        )
    }

    public init(
        specifications: Set<FormatSpecification>,
        mediaType: MediaType? = nil,
        fileExtension: FileExtension? = nil
    ) {
        self.specifications = FormatSpecifications(specifications: specifications)
        self.mediaType = mediaType
        self.fileExtension = fileExtension
    }

    public var hasSpecification: Bool {
        !specifications.specifications.isEmpty
    }

    public func conformsTo(_ specification: FormatSpecification) -> Bool {
        specifications.conformsTo(specification)
    }

    public func conformsToAny(_ specifications: FormatSpecification...) -> Bool {
        self.specifications.conformsToAny(Set(specifications))
    }

    public func conformsToAny(_ specifications: Set<FormatSpecification>) -> Bool {
        self.specifications.conformsToAny(specifications)
    }

    public func conformsToAll(_ specifications: FormatSpecification...) -> Bool {
        self.specifications.conformsToAll(Set(specifications))
    }

    public func conformsToAll(_ specifications: Set<FormatSpecification>) -> Bool {
        self.specifications.conformsToAll(specifications)
    }

    public func refines(_ format: Format) -> Bool {
        if !hasSpecification, format.hasSpecification {
            return true
        } else {
            return specifications.refines(format.specifications)
        }
    }

    public mutating func addSpecifications(_ specifications: FormatSpecification...) {
        for spec in specifications {
            self.specifications.specifications.insert(spec)
        }
    }

    /// Returns a null format, which has no information.
    public static let null = Format(
        specifications: Set(),
        mediaType: nil,
        fileExtension: nil
    )
}

public struct FormatSpecifications: Hashable {
    public var specifications: Set<FormatSpecification>

    public init(_ specifications: FormatSpecification...) {
        self.init(specifications: Set(specifications))
    }

    public init(specifications: Set<FormatSpecification>) {
        self.specifications = specifications
    }

    public func conformsTo(_ specification: FormatSpecification) -> Bool {
        specifications.contains(specification)
    }

    public func conformsToAny(_ specifications: FormatSpecification...) -> Bool {
        conformsToAny(Set(specifications))
    }

    public func conformsToAny(_ specifications: Set<FormatSpecification>) -> Bool {
        specifications.contains { conformsTo($0) }
    }

    public func conformsToAll(_ specifications: FormatSpecification...) -> Bool {
        conformsToAll(Set(specifications))
    }

    public func conformsToAll(_ specifications: Set<FormatSpecification>) -> Bool {
        specifications.allSatisfy { conformsTo($0) }
    }

    public func refines(_ specifications: FormatSpecifications) -> Bool {
        self != specifications && conformsToAll(specifications.specifications)
    }
}

public struct FormatSpecification: RawRepresentable, Hashable {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    // Archive specifications

    public static let rar = FormatSpecification(rawValue: "rar")
    public static let zip = FormatSpecification(rawValue: "zip")

    // Syntax specifications

    public static let json = FormatSpecification(rawValue: "json")
    public static let xml = FormatSpecification(rawValue: "xml")

    // Publication manifest specifications

    public static let rwpm = FormatSpecification(rawValue: "rwpm")

    // Technical document specifications

    public static let problemDetails = FormatSpecification(rawValue: "problem-details")

    // Media format specifications

    public static let pdf = FormatSpecification(rawValue: "pdf")
    public static let html = FormatSpecification(rawValue: "html")

    // DRM specifications

    public static let adept = FormatSpecification(rawValue: "adept")
    public static let lcp = FormatSpecification(rawValue: "lcp")
    public static let lcpLicense = FormatSpecification(rawValue: "lcp-license")

    // Bitmap specifications

    public static let avif = FormatSpecification(rawValue: "avif")
    public static let bmp = FormatSpecification(rawValue: "bmp")
    public static let gif = FormatSpecification(rawValue: "gif")
    public static let jpeg = FormatSpecification(rawValue: "jpeg")
    public static let png = FormatSpecification(rawValue: "png")
    public static let tiff = FormatSpecification(rawValue: "tiff")
    public static let webp = FormatSpecification(rawValue: "webp")

    // Audio specifications

    public static let aac = FormatSpecification(rawValue: "aac")
    public static let aiff = FormatSpecification(rawValue: "aiff")
    public static let flac = FormatSpecification(rawValue: "flac")
    public static let mp4 = FormatSpecification(rawValue: "mp4")
    public static let mp3 = FormatSpecification(rawValue: "mp3")
    public static let ogg = FormatSpecification(rawValue: "ogg")
    public static let opus = FormatSpecification(rawValue: "opus")
    public static let wav = FormatSpecification(rawValue: "wav")
    public static let webm = FormatSpecification(rawValue: "webm")

    // Publication package specifications

    public static let epub = FormatSpecification(rawValue: "epub")
    public static let rpf = FormatSpecification(rawValue: "rpf")
    public static let lpf = FormatSpecification(rawValue: "lpf")
    public static let informalAudiobook = FormatSpecification(rawValue: "informal-audiobook")
    public static let informalComic = FormatSpecification(rawValue: "informal-comic")

    // OPDS specifications

    public static let opds1Catalog = FormatSpecification(rawValue: "opds1-catalog")
    public static let opds1Entry = FormatSpecification(rawValue: "opds1-entry")
    public static let opds2Catalog = FormatSpecification(rawValue: "opds2-catalog")
    public static let opds2Publication = FormatSpecification(rawValue: "opds2-publication")
    public static let opdsAuthentication = FormatSpecification(rawValue: "opds-authentication")

    // Language specifications

    public static let javascript = FormatSpecification(rawValue: "javascript")
    public static let css = FormatSpecification(rawValue: "css")
}
