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
    

    // MARK: Default Supported Formats
    // Formats used by Readium. Reading apps are welcome to extend the static constants with
    // additional formats.
    
    public static let Audiobook = Format(
        name: "Audiobook",
        mediaType: .Audiobook,
        fileExtension: "audiobook"
    )
    
    public static let AudiobookManifest = Format(
        name: "Audiobook",
        mediaType: .AudiobookManifest,
        fileExtension: "json"
    )
    
    public static let BMP = Format(
        name: "BMP",
        mediaType: .BMP,
        fileExtension: "bmp"
    )
    
    public static let CBZ = Format(
        name: "Comic Book Archive",
        mediaType: .CBZ,
        fileExtension: "cbz"
    )
    
    public static let DiViNa = Format(
        name: "Digital Visual Narratives",
        mediaType: .DiViNa,
        fileExtension: "divina"
    )
    
    public static let DiViNaManifest = Format(
        name: "Digital Visual Narratives",
        mediaType: .DiViNaManifest,
        fileExtension: "json"
    )
    
    public static let EPUB = Format(
        name: "EPUB",
        mediaType: .EPUB,
        fileExtension: "epub"
    )
    
    public static let GIF = Format(
        name: "GIF",
        mediaType: .GIF,
        fileExtension: "gif"
    )
    
    public static let HTML = Format(
        name: "HTML",
        mediaType: .HTML,
        fileExtension: "html"
    )
    
    public static let JPEG = Format(
        name: "JPEG",
        mediaType: .JPEG,
        fileExtension: "jpg"
    )
    
    public static let OPDS1Feed = Format(
        name: "OPDS",
        mediaType: .OPDS1,
        fileExtension: "atom"
    )
    
    public static let OPDS1Entry = Format(
        name: "OPDS",
        mediaType: .OPDS1Entry,
        fileExtension: "atom"
    )
    
    public static let OPDS2Feed = Format(
        name: "OPDS",
        mediaType: .OPDS2,
        fileExtension: "json"
    )
    
    public static let OPDS2Publication = Format(
        name: "OPDS",
        mediaType: .OPDS2Publication,
        fileExtension: "json"
    )
    
    public static let LCPProtectedAudiobook = Format(
        name: "LCP Protected Audiobook",
        mediaType: .LCPProtectedAudiobook,
        fileExtension: "lcpa"
    )
    
    public static let LCPProtectedPDF = Format(
        name: "LCP Protected PDF",
        mediaType: .LCPProtectedPDF,
        fileExtension: "lcpdf"
    )
    
    public static let LCPLicense = Format(
        name: "LCP License",
        mediaType: .LCPLicenseDocument,
        fileExtension: "lcpl"
    )
    
    public static let LPF = Format(
        name: "Lightweight Packaging Format",
        mediaType: .LPF,
        fileExtension: "lpf"
    )
    
    public static let PDF = Format(
        name: "PDF",
        mediaType: .PDF,
        fileExtension: "pdf"
    )
    
    public static let PNG = Format(
        name: "PNG",
        mediaType: .PNG,
        fileExtension: "png"
    )
    
    public static let TIFF = Format(
        name: "TIFF",
        mediaType: .TIFF,
        fileExtension: "tiff"
    )
    
    public static let W3CWPUBManifest = Format(
        name: "Web Publication",
        mediaType: .W3CWPUBManifest,
        fileExtension: "json"
    )
    
    public static let WebP = Format(
        name: "WebP",
        mediaType: .WebP,
        fileExtension: "webp"
    )
    
    public static let WebPub = Format(
        name: "Web Publication",
        mediaType: .WebPub,
        fileExtension: "webpub"
    )
    
    public static let WebPubManifest = Format(
        name: "Web Publication",
        mediaType: .WebPubManifest,
        fileExtension: "json"
    )
    
    public static let ZAB = Format(
        name: "Zipped Audio Book",
        mediaType: .ZAB,
        fileExtension: "zab"
    )

    
    // MARK: Equatable
    
    /// Two formats are equal if they have the same media type, regardless of `name` and
    /// `fileExtension`.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.mediaType == rhs.mediaType
    }

}
