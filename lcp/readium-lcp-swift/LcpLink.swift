//
//  LcpLink.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri on 9/8/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import SwiftyJSON

/// A Link to a resource.
public class LcpLink {
    /// The link destination.
    public var href: String?
    /// MIME type of resource.
    public var typeLink: String?
    /// Indicates the relationship between the resource and its containing collection.
    public var rel: [String]!
    /// Indicates the height of the linked resource in pixels.
    public var height: Int?
    /// Indicates the width of the linked resource in pixels.
    public var width: Int?
    public var title: String?
    /// Properties associated to the linked resource.
    public var properties: Properties!
    /// Indicates the length of the linked resource in seconds.
    public var duration: TimeInterval?
    /// Indicates that the linked resource is a URI template.
    public var templated: Bool?

    /// The underlaying nodes in a tree structure of `Link`s.
    public var children: [Link]!
    /// The MediaOverlays associated to the resource of the `Link`.
    public var mediaOverlays: MediaOverlays!

    public init() {
        properties = Properties()
        mediaOverlays = MediaOverlays()
        rel = [String]()
        children = [Link]()
    }

    /// Check wether a link's resource is encrypted by checking is
    /// properties.encrypted is set.
    ///
    /// - Returns: True if encrypted.
    public func isEncrypted() -> Bool {
        guard let properties = properties, let _ = properties.encryption else {
            return false
        }
        return true
    }
}
