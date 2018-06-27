//
//  URLHelper.swift
//  readium-opds
//
//  Created by Geoffrey Bugniot on 07/05/2018.
//  Copyright © 2018 Readium. All rights reserved.
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
            if url.scheme != nil && url.host != nil {
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
