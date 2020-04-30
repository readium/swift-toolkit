//
//  DocumentTypes.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 26.06.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import CoreServices
import Foundation

/// Provides a convenient access layer to the Document Types declared in the `Info.plist`,
/// under `CFBundleDocumentTypes`.
public struct DocumentTypes {
    
    /// Default `DocumentTypes` instance extracted from the main bundle's Info.plist.
    public static let main = DocumentTypes(bundle: .main)
    
    /// List of supported `DocumentType`.
    public let all: [DocumentType]
    
    /// Supported UTIs.
    public let supportedUTIs: [String]
    
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

    // Media (MIME) types recognized by this document type.
    public let mediaTypes: [MediaType]
    // The preferred media type used to identify this document type.
    public let preferredMediaType: MediaType?
    
    // File extensions recognized by this document type.
    public let fileExtensions: [String]
    // The preferred file extension used for this document type.
    public let preferredFileExtension: String?
    
    // R2 Format identifying this document type.
    public let format: Format?
    
    init(
        name: String,
        utis: [String],
        mediaTypes: [MediaType],
        preferredMediaType: MediaType?,
        fileExtensions: [String],
        preferredFileExtension: String?,
        format: Format?
    ) {
        self.name = name
        self.utis = utis
        self.mediaTypes = mediaTypes
        self.preferredMediaType = preferredMediaType
        self.fileExtensions = fileExtensions
        self.preferredFileExtension = preferredFileExtension
        self.format = format
    }
    
    init?(dictionary: [String: Any]) {
        guard let name = dictionary["CFBundleTypeName"] as? String else {
            Self.log(.error, "Document Type without a `CFBundleTypeName`")
            return nil
        }
        
        self.name = name
        self.utis = (dictionary["LSItemContentTypes"] as? [String] ?? [])
        let utis = self.utis.map(UTI.init(stringLiteral:))

        let mediaTypeStrings =
            utis.flatMap { $0.tags(withClass: .mediaType) } +
            (dictionary["CFBundleTypeMIMETypes"] as? [String] ?? [])
        let mediaTypes = mediaTypeStrings.compactMap(MediaType.init)
            .removingDuplicates()
        
        self.mediaTypes = mediaTypes
        self.preferredMediaType =
            utis.preferredTag(withClass: .mediaType).flatMap(MediaType.init)
            ?? mediaTypes.first
        
        let fileExtensions =
            utis.flatMap { $0.tags(withClass: .fileExtension) } +
            (dictionary["CFBundleTypeExtensions"] as? [String] ?? [])
        
        self.fileExtensions = fileExtensions.map { $0.lowercased() }
            .removingDuplicates()
        self.preferredFileExtension =
            utis.preferredTag(withClass: .fileExtension)?.lowercased()
            ?? fileExtensions.first
        
        if let mediaType = preferredMediaType, let fileExtension = preferredFileExtension {
            self.format = Format(name: name, mediaType: mediaType, fileExtension: fileExtension)
        } else {
            self.format = nil
        }
    }

}


// MARK: Deprecated

extension DocumentTypes {
    
    // See this commit for an example of the changes to do in your reading app:
    // https://github.com/readium/r2-testapp-swift/commit/7e98784c01f781c962aab87cd79af09dde900b00
    
    @available(*, deprecated, message: "Use `main.utis` instead", renamed: "main.supportedUTIs")
    public static let utis: [String] = main.supportedUTIs
    @available(*, deprecated, message: "Use `main.supportsMediaType()` instead", renamed: "main.supportsMediaType()")
    public static let contentTypes: [String] = main.supportedMediaTypes.map { $0.string }
    @available(*, deprecated, message: "Use `main.supportsFileExtension()` instead", renamed: "main.supportsFileExtension()")
    public static let extensions: [String] = main.supportedFileExtensions
    
    /// Returns the content type for the given URL.
    @available(*, deprecated, message: "Use `Format.of` to determine the format of a file from its media type or file extension")
    public static func contentType(for url: URL?) -> String? {
        return contentType(forExtension: url?.pathExtension)
    }
    
    /// Returns the content type for the given document extension.
    @available(*, deprecated, message: "Use `Format.of` to determine the format of a file from its media type or file extension")
    public static func contentType(forExtension ext: String?) -> String? {
        guard let fileExtension = ext else {
            return nil
        }
        return Format.of(fileExtension: fileExtension)?.mediaType.string
    }
    
    /// Returns the document extension for given content type.
    @available(*, deprecated, message: "Use `Format.of` to determine the format of a file from its media type or file extension")
    public static func `extension`(forContentType contentType: String?) -> String? {
        guard let mediaType = contentType else {
            return nil
        }
        return Format.of(mediaType: mediaType)?.fileExtension
    }
    
}
