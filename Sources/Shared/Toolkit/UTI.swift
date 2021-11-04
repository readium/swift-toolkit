//
//  UTI.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 26/04/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
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
        self.string = value
    }

    var name: String? {
        UTTypeCopyDescription(string as CFString)?.takeRetainedValue() as String?
    }
    
    /// Returns the preferred tag for this `UTI`, with the given type `tagClass`.
    func preferredTag(withClass tagClass: TagClass) -> String? {
        return UTTypeCopyPreferredTagWithClass(string as CFString, tagClass.rawString)?.takeRetainedValue() as String?
    }

    /// Returns all tags for this `UTI`, with the given type `tagClass`.
    func tags(withClass tagClass: TagClass) -> [String] {
        return UTTypeCopyAllTagsWithClass(string as CFString, tagClass.rawString)?.takeRetainedValue() as? [String]
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
