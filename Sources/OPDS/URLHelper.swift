//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

class URLHelper {
    /**
     Check if an href destination is absolute or not.

     - parameter href: The destination.

     - returns: true only if href is absolute.
     */
    static func isAbsolute(href: String) -> Bool {
        if let url = URL(string: href) {
            if url.scheme != nil, url.host != nil {
                return true
            }
        }

        return false
    }

    /**
     Build an absolute href destination.

     - parameter href: The relative destination.
     - parameter base: The base URL.

     - returns: The absolute href destination.
     */
    static func getAbsolute(href: String?, base: URL?) -> String? {
        var absolute: String?

        if let href = href {
            if URLHelper.isAbsolute(href: href) {
                absolute = href
            } else {
                if let base = base {
                    absolute = URL(string: href, relativeTo: base)?.absoluteString
                }
            }
        }

        return absolute
    }
}
