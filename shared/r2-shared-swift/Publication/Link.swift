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
public struct Link: JSONEquatable {

    /// URI or URI template of the linked resource.
    /// Note: a String because templates are lost with URL.
    public let href: String  // URI

    /// MIME type of the linked resource.
    public let type: String?
    
    /// Indicates that a URI template is used in href.
    public let templated: Bool
    
    /// Title of the linked resource.
    public let title: String?
    
    /// Relation between the linked resource and its containing collection.
    public let rels: [String]
    
    /// Properties associated to the linked resource.
    public let properties: Properties
    
    /// Height of the linked resource in pixels.
    public let height: Int?
    
    /// Width of the linked resource in pixels.
    public let width: Int?
    
    /// Bitrate of the linked resource in kbps.
    public let bitrate: Double?
    
    /// Length of the linked resource in seconds.
    public let duration: Double?
    
    /// Expected language of the linked resource.
    public let languages: [String]  // BCP 47 tag
    
    /// Alternate resources for the linked resource.
    public let alternates: [Link]
    
    /// Resources that are children of the linked resource, in the context of a given collection role.
    public let children: [Link]

    public init(href: String, type: String? = nil, templated: Bool = false, title: String? = nil, rels: [String] = [], rel: String? = nil, properties: Properties = Properties(), height: Int? = nil, width: Int? = nil, bitrate: Double? = nil, duration: Double? = nil, languages: [String] = [], alternates: [Link] = [], children: [Link] = []) {
        // convenience to set a single rel during construction
        var rels = rels
        if let rel = rel {
            rels.append(rel)
        }
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
        self.languages = languages
        self.alternates = alternates
        self.children = children
    }
    
    public init(json: Any, normalizeHref: (String) -> String = { $0 }) throws {
        guard let json = json as? [String: Any],
            let href = json["href"] as? String else
        {
            throw JSONError.parsing(Link.self)
        }
        self.init(
            href: normalizeHref(href),
            type: json["type"] as? String,
            templated: (json["templated"] as? Bool) ?? false,
            title: json["title"] as? String,
            rels: parseArray(json["rel"], allowingSingle: true),
            properties: try Properties(json: json["properties"]) ?? Properties(),
            height: parsePositive(json["height"]),
            width: parsePositive(json["width"]),
            bitrate: parsePositiveDouble(json["bitrate"]),
            duration: parsePositiveDouble(json["duration"]),
            languages: parseArray(json["language"], allowingSingle: true),
            alternates: .init(json: json["alternate"], normalizeHref: normalizeHref),
            children: .init(json: json["children"], normalizeHref: normalizeHref)
        )
    }
    
    public var json: [String: Any] {
        makeJSON([
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
            "language": encodeIfNotEmpty(languages),
            "alternate": encodeIfNotEmpty(alternates.json),
            "children": encodeIfNotEmpty(children.json)
        ])
    }
    
    /// Makes a copy of the `Link`, after modifying some of its properties.
    public func copy(
        href: String? = nil,
        type: String?? = nil,
        templated: Bool? = nil,
        title: String?? = nil,
        rels: [String]? = nil,
        properties: Properties? = nil,
        height: Int?? = nil,
        width: Int?? = nil,
        bitrate: Double?? = nil,
        duration: Double?? = nil,
        languages: [String]? = nil,
        alternates: [Link]? = nil,
        children: [Link]? = nil
    ) -> Link {
        return Link(
            href: href ?? self.href,
            type: type ?? self.type,
            templated: templated ?? self.templated,
            title: title ?? self.title,
            rels: rels ?? self.rels,
            properties: properties ?? self.properties,
            height: height ?? self.height,
            width: width ?? self.width,
            bitrate: bitrate ?? self.bitrate,
            duration: duration ?? self.duration,
            languages: languages ?? self.languages,
            alternates: alternates ?? self.alternates,
            children: children ?? self.children
        )
    }

}


extension Array where Element == Link {
    
    /// Parses multiple JSON links into an array of Link.
    /// eg. let links = [Link](json: [["href", "http://link1"], ["href", "http://link2"]])
    public init(json: Any?, normalizeHref: (String) -> String = { $0 }) {
        self.init()
        guard let json = json as? [Any] else {
            return
        }
        
        let links = json.compactMap { try? Link(json: $0, normalizeHref: normalizeHref) }
        append(contentsOf: links)
    }
    
    public var json: [[String: Any]] {
        map { $0.json }
    }
    
    public func first(withRel rel: String, recursively: Bool = false) -> Link? {
        return first(recursively: recursively) { $0.rels.contains(rel) }
    }
    
    public func first(withHref href: String, recursively: Bool = false) -> Link? {
        return first(recursively: recursively) { $0.href == href }
    }
    
    public func first<T: Equatable>(withProperty otherProperty: String, matching: T, recursively: Bool = false) -> Link? {
        return first(recursively: recursively) { ($0.properties.otherProperties[otherProperty] as? T) == matching }
    }
    
    /// Finds the first link matching the given predicate.
    ///
    /// - Parameter recursively: Finds links recursively through `children`.
    public func first(recursively: Bool, where predicate: (Link) -> Bool) -> Link? {
        return firstIndex(recursively: recursively, where: predicate)
            .map { self[$0] }
    }

    public func firstIndex(withHref href: String, recursively: Bool = false) -> Int? {
        return firstIndex(recursively: recursively) { $0.href == href }
    }
    
    public func firstIndex<T: Equatable>(withProperty otherProperty: String, matching: T, recursively: Bool = false) -> Int? {
        return firstIndex(recursively: recursively) { ($0.properties.otherProperties[otherProperty] as? T) == matching }
    }
    
    /// Finds the index of the first link matching the given predicate.
    ///
    /// - Parameter recursively: Finds links recursively through `children`.
    public func firstIndex(recursively: Bool, where predicate: (Link) -> Bool) -> Int? {
        if !recursively {
            return firstIndex(where: predicate)
        }
        
        for (index, link) in enumerated() {
            if predicate(link) {
                return index
            }
            if let childIndex = link.children.firstIndex(recursively: true, where: predicate) {
                return childIndex
            }
        }
        return nil
    }

}
