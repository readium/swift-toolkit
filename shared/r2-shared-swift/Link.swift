//
//  Link.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri on 2/17/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// A Link to a resource.
public class Link {
    /// The link destination.
    public var href: String?
    /// The link destination (absolute URL).
    public var absoluteHref: String?
    /// MIME type of resource.
    public var typeLink: String?
    /// Indicates the relationship between the resource and its containing collection.
    public var rel = [String]()
    /// Indicates the height of the linked resource in pixels.
    public var height: Int?
    /// Indicates the width of the linked resource in pixels.
    public var width: Int?
    public var title: String?
    /// Properties associated to the linked resource.
    public var properties = Properties()
    /// Indicates the length of the linked resource in seconds.
    public var duration: Float?
  
    /// Indicates that the linked resource is a URI template.
    public var templated: Bool?
    /// Indicate the bitrate for the link resource.
    public var bitrate: Float?
    

    /// The underlaying nodes in a tree structure of `Link`s.
    public var children = [Link]()
    /// The MediaOverlays associated to the resource of the `Link`.
    public var mediaOverlays = MediaOverlays()

    public init() {}

    /// Check wether a link's resource is encrypted by checking is 
    /// properties.encrypted is set.
    ///
    /// - Returns: True if encrypted.
    public func isEncrypted() -> Bool {
        guard let _ = properties.encryption else {
            return false
        }
        return true
    }
}

extension Link: Encodable {
    
    enum CodingKeys: String, CodingKey {
        case duration
        case height
        case href
        case properties
        case rel
        case title
        case type
        case width
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encodeIfPresent(height, forKey: .height)
        try container.encodeIfPresent(href, forKey: .href)
        if !properties.isEmpty() {
            try container.encodeIfPresent(properties, forKey: .properties)
        }
        if !rel.isEmpty {
            try container.encode(rel, forKey: .rel)
        }
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(typeLink, forKey: .type)
        try container.encodeIfPresent(width, forKey: .width)
    }
    
}

// MARK: - Parsing related errors
public enum LinkError: Error {
    case invalidLink
    
    var localizedDescription: String {
        switch self {
        case .invalidLink:
            return "Invalid link"
        }
    }
}

// MARK: - Parsing related methods
extension Link {
    
    static public func parse(linkDict: [String: Any]) throws -> Link {
        let l = Link()
        for (k, v) in linkDict {
            switch k {
            case "title":
                l.title = v as? String
            case "href":
                l.href = v as? String
                l.absoluteHref = v as? String
            case "type":
                l.typeLink = v as? String
            case "rel":
                if let rel = v as? String {
                    l.rel = [rel]
                }
                else if let rels = v as? [String] {
                    l.rel = rels
                }
            case "height":
                l.height = v as? Int
            case "width":
                l.width = v as? Int
            case "bitrate":
                l.bitrate = v as? Float
            case "duration":
                l.duration = v as? Float
            case "templated":
                l.templated = v as? Bool
            case "properties":
                var prop = Properties()
                if let propDict = v as? [String: Any] {
                    for (kp, vp) in propDict {
                        switch kp {
                        case "numberOfItems":
                            prop.numberOfItems = vp as? Int
                        case "indirectAcquisition":
                            guard let acquisitions = vp as? [[String: Any]] else {
                                throw LinkError.invalidLink
                            }
                            for a in acquisitions {
                                let ia = try IndirectAcquisition.parse(indirectAcquisitionDict: a)
                                if prop.indirectAcquisition == nil {
                                    prop.indirectAcquisition = [ia]
                                }
                                else {
                                    prop.indirectAcquisition!.append(ia)
                                }
                            }
                        case "price":
                            guard let priceDict = vp as? [String: Any],
                                let currency = priceDict["currency"] as? String,
                                let value = priceDict["value"] as? Double
                                else {
                                    throw LinkError.invalidLink
                            }
                            let price = Price(currency: currency, value: value)
                            prop.price = price
                        default:
                            continue
                        }
                    }
                }
                l.properties = prop
            case "children":
                guard let childLinkDict = v as? [String: Any] else {
                    throw LinkError.invalidLink
                }
                let childLink = try parse(linkDict: childLinkDict)
                l.children.append(childLink)
            default:
                continue
            }
        }
        return l
    }
    
}
