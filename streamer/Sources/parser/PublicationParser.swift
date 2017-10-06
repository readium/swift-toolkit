//
//  PublicationParser.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 4/4/17.
//  Copyright © 2017 Readium. All rights reserved.
//

/// Normalize a path relative path given the base path.
internal func normalize(base: String, href: String?) -> String {
    guard let href = href, !href.isEmpty else {
        return ""
    }
    let hrefComponents = href.components(separatedBy: "/").filter({!$0.isEmpty})
    var baseComponents = base.components(separatedBy: "/").filter({!$0.isEmpty})

    // Remove the /folder/folder/"PATH.extension" part to keep only the path.
    _ = baseComponents.popLast()
    // Find the number of ".." in the path to replace them.
    let replacementsNumber = hrefComponents.filter({$0 == ".."}).count
    // Get the valid part of href, reversed for next operation.
    var normalizedComponents = hrefComponents.filter({$0 != ".."})
    // Add the part from base to replace the "..".
    for _ in 0..<replacementsNumber {
        _ = baseComponents.popLast()
    }
    normalizedComponents = baseComponents + normalizedComponents
    // Recreate a string.
    var normalizedString = ""
    for component in normalizedComponents {
        normalizedString.append("/\(component)")
    }
    return normalizedString
}
