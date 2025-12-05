//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import CoreServices
import Foundation
import ReadiumInternal

#if canImport(UniformTypeIdentifiers)
    import UniformTypeIdentifiers
#endif

/// Provides a convenient access layer to the Document Types declared in the `Info.plist`,
/// under `CFBundleDocumentTypes`.
public struct DocumentTypes {
    /// Default `DocumentTypes` instance extracted from the main bundle's Info.plist.
    public static let main = DocumentTypes(bundle: .main)

    /// List of supported `DocumentType`.
    public let all: [DocumentType]

    /// Supported UTIs.
    public let supportedUTIs: [String]

    /// Supported UTTypes.
    @available(iOS 14.0, *)
    public var supportedUTTypes: [UTType] {
        supportedUTIs.compactMap { UTType($0) }
    }

    /// Supported document media types.
    public let supportedMediaTypes: [MediaType]

    /// Supported document file extensions.
    public let supportedFileExtensions: [String]

    /// Extracts the Document Types declared in the given `bundle`.
    public init(bundle: Bundle) {
        self.init(infoDictionary: bundle.infoDictionary)
    }

    init(infoDictionary: [String: Any]?) {
        let types = (infoDictionary?["CFBundleDocumentTypes"] as? [[String: Any]] ?? [])
            .compactMap { DocumentType(dictionary: $0) }

        all = types

        supportedUTIs = types
            .flatMap(\.utis)
            .removingDuplicates()

        let utis = supportedUTIs.map(UTI.init(stringLiteral:))

        let utisMediaTypes = utis
            .flatMap { $0.tags(withClass: .mediaType) }
            .compactMap { MediaType($0) }

        let utisFileExtensions = utis.flatMap { $0.tags(withClass: .fileExtension) }

        supportedMediaTypes = (utisMediaTypes + types.flatMap(\.mediaTypes))
            .removingDuplicates()

        supportedFileExtensions = (utisFileExtensions + types.flatMap(\.fileExtensions))
            .map { $0.lowercased() }
            .removingDuplicates()
    }

    /// Returns whether the given `mediaType` is supported in the app.
    public func supportsMediaType(_ mediaType: String?) -> Bool {
        guard let mediaType = mediaType else {
            return false
        }
        for supportedMediaType in supportedMediaTypes {
            if supportedMediaType.contains(mediaType) {
                return true
            }
        }
        return false
    }

    /// Returns whether the given `fileExtension` is supported in the app.
    public func supportsFileExtension(_ fileExtension: String?) -> Bool {
        guard let fileExtension = fileExtension else {
            return false
        }
        return supportedFileExtensions.contains(fileExtension.lowercased())
    }
}

/// Metadata about a Document Type declared in `CFBundleDocumentTypes`.
public struct DocumentType: Equatable, Loggable {
    // Abstract name for the document type, used to refer to the type.
    public let name: String

    // Uniform Type Identifiers supported by this document type.
    public let utis: [String]

    // The preferred media type used to identify this document type.
    public let preferredMediaType: MediaType?

    // Media (MIME) types recognized by this document type.
    public let mediaTypes: [MediaType]
    // File extensions recognized by this document type.
    public let fileExtensions: [String]

    init(
        name: String,
        utis: [String],
        preferredMediaType: MediaType?,
        mediaTypes: [MediaType],
        fileExtensions: [String]
    ) {
        self.name = name
        self.utis = utis
        self.preferredMediaType = preferredMediaType
        self.mediaTypes = mediaTypes
        self.fileExtensions = fileExtensions
    }

    init?(dictionary: [String: Any]) {
        guard let name = dictionary["CFBundleTypeName"] as? String else {
            Self.log(.error, "Document Type without a `CFBundleTypeName`")
            return nil
        }

        self.name = name
        self.utis = (dictionary["LSItemContentTypes"] as? [String] ?? [])
        let utis = utis.map(UTI.init(stringLiteral:))

        let fileExtensions =
            utis.flatMap { $0.tags(withClass: .fileExtension) } +
            (dictionary["CFBundleTypeExtensions"] as? [String] ?? [])

        self.fileExtensions = fileExtensions
            .map { $0.lowercased() }
            .removingDuplicates()

        let mediaTypeStrings =
            utis.flatMap { $0.tags(withClass: .mediaType) } +
            (dictionary["CFBundleTypeMIMETypes"] as? [String] ?? [])
        let mediaTypes = mediaTypeStrings.compactMap { MediaType($0) }
            .removingDuplicates()

        self.mediaTypes = mediaTypes

        preferredMediaType = utis.preferredTag(withClass: .mediaType)
            .flatMap { MediaType($0) }
            ?? mediaTypes.first
    }
}
