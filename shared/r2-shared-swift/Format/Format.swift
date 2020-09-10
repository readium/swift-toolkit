//
//  Format.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 10/04/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// Represents a known file format, uniquely identified by a media type.
public struct Format: Equatable, Hashable, Loggable {

    /// A human readable name identifying the format, which might be presented to the user.
    public let name: String
    
    /// The canonical media type that identifies the best (most officially) this format.
    public let mediaType: MediaType
    
    /// The default file extension to use for this format.
    public let fileExtension: String
    
    /// Returns whether this format is declared in the Document Types section of the app's main bundle.
    public var isSupportedDocumentType: Bool {
        return mediaType.isSupportedDocumentType
            || DocumentTypes.main.supportsFileExtension(fileExtension)
    }
    

    // MARK: Default Supported Formats
    // Formats used by Readium. Reading apps are welcome to extend the static constants with
    // additional formats.

    public static let bmp = Format(
        name: "BMP",
        mediaType: .bmp,
        fileExtension: "bmp"
    )
    
    public static let cbz = Format(
        name: "Comic Book Archive",
        mediaType: .cbz,
        fileExtension: "cbz"
    )
    
    public static let divina = Format(
        name: "Digital Visual Narratives",
        mediaType: .divina,
        fileExtension: "divina"
    )
    
    public static let divinaManifest = Format(
        name: "Digital Visual Narratives",
        mediaType: .divinaManifest,
        fileExtension: "json"
    )
    
    public static let epub = Format(
        name: "EPUB",
        mediaType: .epub,
        fileExtension: "epub"
    )
    
    public static let gif = Format(
        name: "GIF",
        mediaType: .gif,
        fileExtension: "gif"
    )
    
    public static let html = Format(
        name: "HTML",
        mediaType: .html,
        fileExtension: "html"
    )
    
    public static let jpeg = Format(
        name: "JPEG",
        mediaType: .jpeg,
        fileExtension: "jpg"
    )

    public static let lcpProtectedAudiobook = Format(
        name: "LCP Protected Audiobook",
        mediaType: .lcpProtectedAudiobook,
        fileExtension: "lcpa"
    )
    
    public static let lcpProtectedPDF = Format(
        name: "LCP Protected PDF",
        mediaType: .lcpProtectedPDF,
        fileExtension: "lcpdf"
    )
    
    public static let lcpLicense = Format(
        name: "LCP License",
        mediaType: .lcpLicenseDocument,
        fileExtension: "lcpl"
    )
    
    public static let lpf = Format(
        name: "Lightweight Packaging Format",
        mediaType: .lpf,
        fileExtension: "lpf"
    )
    
    public static let opds1Feed = Format(
        name: "OPDS",
        mediaType: .opds1,
        fileExtension: "atom"
    )
    
    public static let opds1Entry = Format(
        name: "OPDS",
        mediaType: .opds1Entry,
        fileExtension: "atom"
    )
    
    public static let opds2Feed = Format(
        name: "OPDS",
        mediaType: .opds2,
        fileExtension: "json"
    )
    
    public static let opds2Publication = Format(
        name: "OPDS",
        mediaType: .opds2Publication,
        fileExtension: "json"
    )
    
    public static let opdsAuthentication = Format(
        name: "OPDS Authentication Document",
        mediaType: .opdsAuthentication,
        fileExtension: "json"
    )
    
    public static let pdf = Format(
        name: "PDF",
        mediaType: .pdf,
        fileExtension: "pdf"
    )
    
    public static let png = Format(
        name: "PNG",
        mediaType: .png,
        fileExtension: "png"
    )
    
    public static let readiumAudiobook = Format(
        name: "Readium Audiobook",
        mediaType: .readiumAudiobook,
        fileExtension: "audiobook"
    )
    
    public static let readiumAudiobookManifest = Format(
        name: "Readium Audiobook",
        mediaType: .readiumAudiobookManifest,
        fileExtension: "json"
    )
    
    public static let readiumWebPub = Format(
        name: "Readium Web Publication",
        mediaType: .readiumWebPub,
        fileExtension: "webpub"
    )
    
    public static let readiumWebPubManifest = Format(
        name: "Readium Web Publication",
        mediaType: .readiumWebPubManifest,
        fileExtension: "json"
    )

    public static let tiff = Format(
        name: "TIFF",
        mediaType: .tiff,
        fileExtension: "tiff"
    )
    
    public static let w3cWPUBManifest = Format(
        name: "Web Publication",
        mediaType: .w3cWPUBManifest,
        fileExtension: "json"
    )
    
    public static let webp = Format(
        name: "WebP",
        mediaType: .webp,
        fileExtension: "webp"
    )
    
    public static let zab = Format(
        name: "Zipped Audio Book",
        mediaType: .zab,
        fileExtension: "zab"
    )

    
    @available(*, unavailable, renamed: "readiumAudiobook")
    public static var audiobook: Format { readiumAudiobook }
    @available(*, unavailable, renamed: "readiumAudiobookManifest")
    public static var audiobookManifest: Format { readiumAudiobookManifest }
    @available(*, unavailable, renamed: "readiumWebPub")
    public static var webpub: Format { readiumWebPub }
    @available(*, unavailable, renamed: "readiumWebPubManifest")
    public static var webpubManifest: Format { readiumWebPubManifest }


    // MARK: Equatable
    
    /// Two formats are equal if they have the same media type, regardless of `name` and
    /// `fileExtension`.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.mediaType.string == rhs.mediaType.string
    }

}
