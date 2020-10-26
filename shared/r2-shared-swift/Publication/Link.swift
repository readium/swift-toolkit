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
public struct Link: JSONEquatable, Hashable {

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
    public let rels: [LinkRelation]
    
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

    public init(href: String, type: String? = nil, templated: Bool = false, title: String? = nil, rels: [LinkRelation] = [], rel: LinkRelation? = nil, properties: Properties = Properties(), height: Int? = nil, width: Int? = nil, bitrate: Double? = nil, duration: Double? = nil, languages: [String] = [], alternates: [Link] = [], children: [Link] = []) {
        // Convenience to set a single rel during construction.
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
    
    public init(json: Any, warnings: WarningLogger? = nil, normalizeHREF: (String) -> String = { $0 }) throws {
        guard let jsonObject = json as? [String: Any],
            let href = jsonObject["href"] as? String else
        {
            warnings?.log("`href` is required", model: Self.self, source: json)
            throw JSONError.parsing(Self.self)
        }
        self.init(
            href: normalizeHREF(href),
            type: jsonObject["type"] as? String,
            templated: (jsonObject["templated"] as? Bool) ?? false,
            title: jsonObject["title"] as? String,
            rels: .init(json: jsonObject["rel"]),
            properties: (try? Properties(json: jsonObject["properties"], warnings: warnings)) ?? Properties(),
            height: parsePositive(jsonObject["height"]),
            width: parsePositive(jsonObject["width"]),
            bitrate: parsePositiveDouble(jsonObject["bitrate"]),
            duration: parsePositiveDouble(jsonObject["duration"]),
            languages: parseArray(jsonObject["language"], allowingSingle: true),
            alternates: .init(json: jsonObject["alternate"], warnings: warnings, normalizeHREF: normalizeHREF),
            children: .init(json: jsonObject["children"], warnings: warnings, normalizeHREF: normalizeHREF)
        )
    }
    
    public var json: [String: Any] {
        makeJSON([
            "href": href,
            "type": encodeIfNotNil(type),
            "templated": templated,
            "title": encodeIfNotNil(title),
            "rel": encodeIfNotEmpty(rels.json),
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
    
    /// Computes an absolute URL to the link, relative to the given `baseURL`.
    ///
    /// If the link's `href` is already absolute, the `baseURL` is ignored.
    public func url(relativeTo baseURL: URL?) -> URL? {
        if let url = URL(string: href), url.scheme != nil {
            return url
        } else {
            let safeHREF = (href.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? href).removingPrefix("/")
            return URL(string: safeHREF, relativeTo: baseURL)?.absoluteURL
        }
    }
    
    
    // MARK: URI Template
    
    /// List of URI template parameter keys, if the `Link` is templated.
    public var templateParameters: Set<String> {
        guard templated else {
            return []
        }
        return URITemplate(href).parameters
    }

    /// Expands the `Link`'s HREF by replacing URI template variables by the given parameters.
    ///
    /// See RFC 6570 on URI template: https://tools.ietf.org/html/rfc6570
    public func expandTemplate(with parameters: [String: String]) -> Link {
        guard templated else {
            return self
        }
        return copy(
            href: URITemplate(href).expand(with: parameters),
            templated: false
        )
    }
    
    
    // MARK: Copy
    
    /// Makes a copy of the `Link`, after modifying some of its properties.
    public func copy(
        href: String? = nil,
        type: String?? = nil,
        templated: Bool? = nil,
        title: String?? = nil,
        rels: [LinkRelation]? = nil,
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
    
    ///  Makes a copy of this `Link` after merging in the given additional other `properties`.
    public func addingProperties(_ properties: [String: Any]) -> Link {
        copy(properties: self.properties.adding(properties))
    }

}


extension Array where Element == Link {
    
    /// Parses multiple JSON links into an array of Link.
    /// eg. let links = [Link](json: [["href", "http://link1"], ["href", "http://link2"]])
    public init(json: Any?, warnings: WarningLogger? = nil, normalizeHREF: (String) -> String = { $0 }) {
        self.init()
        guard let json = json as? [Any] else {
            return
        }
        
        let links = json.compactMap { try? Link(json: $0, warnings: warnings, normalizeHREF: normalizeHREF) }
        append(contentsOf: links)
    }
    
    public var json: [[String: Any]] {
        map { $0.json }
    }
    
    /// Finds the first link with the given relation.
    public func first(withRel rel: LinkRelation) -> Link? {
        return first { $0.rels.contains(rel) }
    }

    /// Finds all the links with the given relation.
    public func filter(byRel rel: LinkRelation) -> [Link] {
        return filter { $0.rels.contains(rel) }
    }
    
    /// Finds the first link matching the given HREF.
    public func first(withHREF href: String) -> Link? {
        return first { $0.href == href }
    }

    /// Finds the index of the first link matching the given HREF.
    public func firstIndex(withHREF href: String) -> Int? {
        return firstIndex { $0.href == href }
    }

    /// Finds the first link matching the given media type.
    public func first(withMediaType mediaType: MediaType) -> Link? {
        return first { mediaType.matches($0.type) }
    }
    
    /// Finds all the links matching the given media type.
    public func filter(byMediaType mediaType: MediaType) -> [Link] {
        return filter { mediaType.matches($0.type) }
    }
    
    /// Finds all the links matching any of the given media types.
    public func filter(byMediaTypes mediaTypes: [MediaType]) -> [Link] {
        return filter { link in
            mediaTypes.contains { mediaType in
                mediaType.matches(link.type)
            }
        }
    }
    
    /// Returns whether all the resources in the collection are bitmaps.
    public var allAreBitmap: Bool {
        allSatisfy { $0.mediaType?.isBitmap == true }
    }
    
    /// Returns whether all the resources in the collection are audio clips.
    public var allAreAudio: Bool {
        allSatisfy { $0.mediaType?.isAudio == true }
    }
    
    /// Returns whether all the resources in the collection are video clips.
    public var allAreVideo: Bool {
        allSatisfy { $0.mediaType?.isVideo == true }
    }
    
    /// Returns whether all the resources in the collection are HTML documents.
    public var allAreHTML: Bool {
        allSatisfy { $0.mediaType?.isHTML == true }
    }
    
    /// Returns whether all the resources in the collection are matching the given media type.
    public func all(matchMediaType mediaType: MediaType) -> Bool {
        allSatisfy { mediaType.matches($0.type) }
    }
    
    /// Returns whether all the resources in the collection are matching any of the given media types.
    public func all(matchMediaTypes mediaTypes: [MediaType]) -> Bool {
        allSatisfy { link in
            mediaTypes.contains { mediaType in
                mediaType.matches(link.type)
            }
        }
    }
    
    @available(*, deprecated, message: "This API will be removed.")
    public func firstIndex<T: Equatable>(withProperty otherProperty: String, matching: T, recursively: Bool = false) -> Int? {
        return firstIndex { ($0.properties.otherProperties[otherProperty] as? T) == matching }
    }
    
    @available(*, deprecated, renamed: "first(withHREF:)")
    public func first(withHref href: String) -> Link? {
        return first(withHREF: href)
    }
    
    @available(*, deprecated, renamed: "firstIndex(withHREF:)")
    public func firstIndex(withHref href: String) -> Int? {
        return firstIndex(withHREF: href)
    }
    
}
