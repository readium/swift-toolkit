//
//  Link.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 09.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation


/// Link Object for the Readium Web Publication Manifest.
/// https://readium.org/webpub-manifest/schema/link.schema.json
///
/// Note: This is not a struct because in certain situations Link has an Identity (eg. EPUB), and rely on a reference to manipulate the links.
public class Link: Equatable {

    /// URI or URI template of the linked resource.
    /// Note: a String because templates are lost with URL.
    public var href: String  // URI

    /// MIME type of the linked resource.
    public var type: String?
    
    /// Indicates that a URI template is used in href.
    public var templated: Bool
    
    /// Title of the linked resource.
    public var title: String?
    
    /// Relation between the linked resource and its containing collection.
    public var rels: [String]
    
    /// Properties associated to the linked resource.
    public var properties: Properties
    
    /// Height of the linked resource in pixels.
    public var height: Int?
    
    /// Width of the linked resource in pixels.
    public var width: Int?
    
    /// Bitrate of the linked resource in kbps.
    public var bitrate: Double?
    
    /// Length of the linked resource in seconds.
    public var duration: Double?
    
    /// Resources that are children of the linked resource, in the context of a given collection role.
    public var children: [Link]

    /// FIXME: This is used when parsing EPUB's media overlays, but maybe it should be stored somewhere else?
    /// The MediaOverlays associated to the resource of the `Link`.
    public var mediaOverlays = MediaOverlays()
    
    
    public init(href: String, type: String? = nil, templated: Bool = false, title: String? = nil, rels: [String] = [], rel: String? = nil, properties: Properties = Properties(), height: Int? = nil, width: Int? = nil, bitrate: Double? = nil, duration: Double? = nil, children: [Link] = []) {
        self.href = href
        self.type = type
        self.templated = templated
        self.title = title
        self.rels = rels
        self.properties = properties
        self.height = height
        self.width = width
        self.bitrate = bitrate
        self.duration = duration
        self.children = children
        
        // convenience to set a single rel during construction
        if let rel = rel {
            self.rels.append(rel)
        }
    }
    
    public init(json: Any) throws {
        guard let json = json as? [String: Any],
            let href = json["href"] as? String else
        {
            throw JSONParsingError.link
        }
        self.href = href
        self.type = json["type"] as? String
        self.templated = (json["templated"] as? Bool) ?? false
        self.title = json["title"] as? String
        self.rels = parseArray(json["rel"], allowingSingle: true)
        self.properties = try Properties(json: json["properties"]) ?? Properties()
        self.height = parsePositive(json["height"])
        self.width = parsePositive(json["width"])
        self.bitrate = parsePositiveDouble(json["bitrate"])
        self.duration = parsePositiveDouble(json["duration"])
        self.children = [Link](json: json["children"])
    }
    
    public var json: [String: Any] {
        return makeJSON([
            "href": href,
            "type": encodeIfNotNil(type),
            "templated": templated,
            "title": encodeIfNotNil(title),
            "rel": encodeIfNotEmpty(rels),
            "properties": encodeIfNotEmpty(properties.json),
            "height": encodeIfNotNil(height),
            "width": encodeIfNotNil(width),
            "bitrate": encodeIfNotNil(bitrate),
            "duration": encodeIfNotNil(duration),
            "children": encodeIfNotEmpty(children.json)
        ])
    }
    
    public static func == (lhs: Link, rhs: Link) -> Bool {
        guard #available(iOS 11.0, *) else {
            // The JSON comparison is not reliable before iOS 11, because the keys order is not deterministic. Since the equality is only tested during unit tests, it's not such a problem.
            return false
        }
        
        let l = try? JSONSerialization.data(withJSONObject: lhs.json, options: [.sortedKeys])
        let r = try? JSONSerialization.data(withJSONObject: rhs.json, options: [.sortedKeys])
        return l == r
    }

    @available(*, deprecated, renamed: "type")
    public var typeLink: String? { get { return type } set { type = newValue } }
    
    @available(*, deprecated, renamed: "rels")
    public var rel: [String] { get { return rels } set { rels = newValue } }
    
    @available(*, deprecated, renamed: "href")
    public var absoluteHref: String? { get { return href } set { href = newValue ?? href } }
    
    @available(*, deprecated, renamed: "Link(href:)")
    public convenience init() {
        self.init(href: "")
    }
    
    @available(*, deprecated, renamed: "init(json:)")
    static public func parse(linkDict: [String: Any]) throws -> Link {
        return try Link(json: linkDict)
    }
    
}

extension Array where Element == Link {
    
    /// Parses multiple JSON links into an array of Link.
    /// eg. let links = [Link](json: [["href", "http://link1"], ["href", "http://link2"]])
    public init(json: Any?) {
        self.init()
        guard let json = json as? [Any] else {
            return
        }
        
        let links = json.compactMap { try? Link(json: $0) }
        append(contentsOf: links)
    }
    
    public var json: [[String: Any]] {
        return map { $0.json }
    }
    
}
