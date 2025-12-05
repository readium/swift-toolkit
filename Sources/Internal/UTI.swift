//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import CoreServices
import Foundation

/// Uniform Type Identifier.
public struct UTI: ExpressibleByStringLiteral {
    /// Type tag class, eg. kUTTagClassMIMEType.
    public enum TagClass {
        case mediaType, fileExtension

        var rawString: CFString {
            switch self {
            case .mediaType:
                return kUTTagClassMIMEType
            case .fileExtension:
                return kUTTagClassFilenameExtension
            }
        }
    }

    public let string: String

    public init(stringLiteral value: StringLiteralType) {
        string = value
    }

    public var name: String? {
        UTTypeCopyDescription(string as CFString)?.takeRetainedValue() as String?
    }

    /// Returns the preferred tag for this `UTI`, with the given type `tagClass`.
    public func preferredTag(withClass tagClass: TagClass) -> String? {
        UTTypeCopyPreferredTagWithClass(string as CFString, tagClass.rawString)?.takeRetainedValue() as String?
    }

    /// Returns all tags for this `UTI`, with the given type `tagClass`.
    public func tags(withClass tagClass: TagClass) -> [String] {
        UTTypeCopyAllTagsWithClass(string as CFString, tagClass.rawString)?.takeRetainedValue() as? [String]
            ?? []
    }

    /// Finds the first `UTI` recognizing any of the given `mediaTypes` or `fileExtensions`.
    public static func findFrom(mediaTypes: [String], fileExtensions: [String]) -> UTI? {
        for mediaType in mediaTypes {
            if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mediaType as CFString, nil)?.takeUnretainedValue() {
                return UTI(stringLiteral: uti as String)
            }
        }
        for fileExtension in fileExtensions {
            if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExtension as CFString, nil)?.takeUnretainedValue() {
                return UTI(stringLiteral: uti as String)
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
