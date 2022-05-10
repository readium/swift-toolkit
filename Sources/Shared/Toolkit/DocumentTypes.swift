//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import CoreServices
import Foundation

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
        
        self.all = types
        
        self.supportedUTIs = types
            .flatMap { $0.utis }
            .removingDuplicates()
        
        let utis = supportedUTIs.map(UTI.init(stringLiteral:))
        
        let utisMediaTypes = utis
            .flatMap { $0.tags(withClass: .mediaType) }
            .compactMap { MediaType($0) }
        
        let utisFileExtensions = utis.flatMap { $0.tags(withClass: .fileExtension) }
        
        self.supportedMediaTypes = (utisMediaTypes + types.flatMap({ $0.mediaTypes }))
            .removingDuplicates()
        
        self.supportedFileExtensions = (utisFileExtensions + types.flatMap({ $0.fileExtensions }))
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
        let utis = self.utis.map(UTI.init(stringLiteral:))

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

        let preferredFileExtension =
            utis.preferredTag(withClass: .fileExtension)
                ?? fileExtensions.first

        self.preferredMediaType = utis.preferredTag(withClass: .mediaType)
            .flatMap { MediaType($0, name: name, fileExtension: preferredFileExtension?.lowercased()) }
            ?? mediaTypes.first
    }

    @available(*, unavailable, renamed: "preferredMediaType")
    public var format: MediaType? { preferredMediaType }

}


// MARK: Deprecated

extension DocumentTypes {
    
    // See this commit for an example of the changes to do in your reading app:
    // https://github.com/readium/r2-testapp-swift/commit/7e98784c01f781c962aab87cd79af09dde900b00
    
    @available(*, unavailable, message: "Use `main.utis` instead", renamed: "main.supportedUTIs")
    public static let utis: [String] = main.supportedUTIs
    @available(*, unavailable, message: "Use `main.supportsMediaType()` instead", renamed: "main.supportsMediaType()")
    public static let contentTypes: [String] = main.supportedMediaTypes.map { $0.string }
    @available(*, unavailable, message: "Use `main.supportsFileExtension()` instead", renamed: "main.supportsFileExtension()")
    public static let extensions: [String] = main.supportedFileExtensions
    
    /// Returns the content type for the given URL.
    @available(*, unavailable, message: "Use `Format.of` to determine the format of a file from its media type or file extension")
    public static func contentType(for url: URL?) -> String? { nil }
    
    /// Returns the content type for the given document extension.
    @available(*, unavailable, message: "Use `Format.of` to determine the format of a file from its media type or file extension")
    public static func contentType(forExtension ext: String?) -> String? {
        guard let fileExtension = ext else {
            return nil
        }
        return MediaType.of(fileExtension: fileExtension)?.string
    }
    
    /// Returns the document extension for given content type.
    @available(*, unavailable, message: "Use `Format.of` to determine the format of a file from its media type or file extension")
    public static func `extension`(forContentType contentType: String?) -> String? {
        guard let mediaType = contentType else {
            return nil
        }
        return MediaType.of(mediaType: mediaType)?.fileExtension
    }

}
