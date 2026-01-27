//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import UniformTypeIdentifiers

/// Uniform Type Identifier.
public struct UTI {
    /// Type tag class, eg. UTTagClass.mimeType.
    public enum TagClass {
        case mediaType, fileExtension
    }

    public let type: UTType

    public init(type: UTType) {
        self.type = type
    }

    public init?(_ identifier: String) {
        guard let type = UTType(identifier) else {
            return nil
        }
        self.init(type: type)
    }

    public init?(mediaType: String) {
        guard let type = UTType(mimeType: mediaType) else {
            return nil
        }
        self.init(type: type)
    }

    public init?(fileExtension: String) {
        guard let type = UTType(filenameExtension: fileExtension) else {
            return nil
        }
        self.init(type: type)
    }

    public var name: String? { type.localizedDescription }

    public var string: String { type.identifier }

    /// Returns the preferred tag for this `UTI`, with the given type `tagClass`.
    public func preferredTag(withClass tagClass: TagClass) -> String? {
        switch tagClass {
        case .mediaType:
            return type.preferredMIMEType
        case .fileExtension:
            return type.preferredFilenameExtension
        }
    }

    /// Returns all tags for this `UTI`, with the given type `tagClass`.
    public func tags(withClass tagClass: TagClass) -> [String] {
        switch tagClass {
        case .mediaType:
            return type.tags[.mimeType] ?? []
        case .fileExtension:
            return type.tags[.filenameExtension] ?? []
        }
    }

    /// Finds the first `UTI` recognizing any of the given `mediaTypes` or `fileExtensions`.
    public static func findFrom(mediaTypes: [String], fileExtensions: [String]) -> UTI? {
        for mediaType in mediaTypes {
            if let uti = UTI(mediaType: mediaType) {
                return uti
            }
        }
        for fileExtension in fileExtensions {
            if let uti = UTI(fileExtension: fileExtension) {
                return uti
            }
        }
        return nil
    }
}

public extension Array where Element == UTI {
    /// Returns the first preferred tag found in the list of `UTI`, with the given type `tagClass`.
    func preferredTag(withClass tagClass: UTI.TagClass) -> String? {
        for uti in self {
            if let tag = uti.preferredTag(withClass: tagClass) {
                return tag
            }
        }
        return nil
    }
}
