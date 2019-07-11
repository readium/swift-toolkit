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

public final class DocumentTypes {
    
    // Extracts supported Document Types from the main bundle's Info.plist.
    private static let types = (Bundle.main.object(forInfoDictionaryKey: "CFBundleDocumentTypes") as? [[String: Any]] ?? [])
    
    /// Supported UTI.
    public static let utis: [String] = types
        .flatMap { $0["LSItemContentTypes"] as? [String] ?? [] }

    /// Supported document content types.
    public static let contentTypes: [String] = utis
        .compactMap { UTTypeCopyPreferredTagWithClass($0 as CFString, kUTTagClassMIMEType)?.takeRetainedValue() as String? }
    
    /// Supported document extensions.
    public static let extensions: [String] = types
        .flatMap { $0["CFBundleTypeExtensions"] as? [String] ?? [] }
        .map { $0.lowercased() }
    
    /// Returns the content type for the given URL.
    public static func contentType(for url: URL?) -> String? {
        return contentType(forExtension: url?.pathExtension)
    }
    
    /// Returns the content type for the given document extension.
    public static func contentType(forExtension ext: String?) -> String? {
        guard let ext = ext else {
            return nil
        }
        return (UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, ext as CFString, nil)?.takeUnretainedValue())
            .flatMap { UTTypeCopyPreferredTagWithClass($0, kUTTagClassMIMEType)?.takeRetainedValue() as String? }
    }
    
    /// Returns the document extension for given content type.
    public static func `extension`(forContentType contentType: String?) -> String? {
        guard let contentType = contentType else {
            return nil
        }
        return (UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, contentType as CFString, nil)?.takeUnretainedValue())
            .flatMap { UTTypeCopyPreferredTagWithClass($0, kUTTagClassFilenameExtension)?.takeRetainedValue() as String? }
    }

}
