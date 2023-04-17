//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import CoreServices
import Foundation

/// Uniform Type Identifier.
struct UTI: ExpressibleByStringLiteral {
    /// Type tag class, eg. kUTTagClassMIMEType.
    enum TagClass {
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

    let string: String

    init(stringLiteral value: StringLiteralType) {
        string = value
    }

    var name: String? {
        UTTypeCopyDescription(string as CFString)?.takeRetainedValue() as String?
    }

    /// Returns the preferred tag for this `UTI`, with the given type `tagClass`.
    func preferredTag(withClass tagClass: TagClass) -> String? {
        UTTypeCopyPreferredTagWithClass(string as CFString, tagClass.rawString)?.takeRetainedValue() as String?
    }

    /// Returns all tags for this `UTI`, with the given type `tagClass`.
    func tags(withClass tagClass: TagClass) -> [String] {
        UTTypeCopyAllTagsWithClass(string as CFString, tagClass.rawString)?.takeRetainedValue() as? [String]
            ?? []
    }

    /// Finds the first `UTI` recognizing any of the given `mediaTypes` or `fileExtensions`.
    static func findFrom(mediaTypes: [MediaType], fileExtensions: [String]) -> UTI? {
        for mediaType in mediaTypes {
            if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mediaType.string as CFString, nil)?.takeUnretainedValue() {
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

extension Array where Element == UTI {
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
