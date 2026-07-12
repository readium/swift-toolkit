//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public extension String {
    /// Returns this string after removing any character forbidden in a single path component.
    nonisolated var sanitizedPathComponent: String {
        // See https://superuser.com/a/358861
        let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
            .union(.newlines)
            .union(.illegalCharacters)
            .union(.controlCharacters)

        return components(separatedBy: invalidCharacters)
            .joined(separator: " ")
    }
}
