//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

public enum LinkError: Error, Equatable {
    /// The link's HREF is not a valid URL.
    case invalidHREF(String)
}

/// Link Object for the Readium Web Publication Manifest.
/// https://readium.org/webpub-manifest/schema/link.schema.json
public struct Link: JSONEquatable, Hashable, Sendable {
    /// URI or URI template of the linked resource.
    /// Note: a String because templates are lost with URL.
    public var href: String // URI

    /// Media type of the linked resource.
    public var mediaType: MediaType?

    /// Indicates that a URI template is used in href.
    public var templated: Bool

    /// Title of the linked resource.
    public var title: String?

    /// Relation between the linked resource and its containing collection.
    public var rels: [LinkRelation]

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

    /// Expected language of the linked resource.
    public var languages: [String] // BCP 47 tag

    /// Alternate resources for the linked resource.
    public var alternates: [Link]

    /// Resources that are children of the linked resource, in the context of a given collection role.
    public var children: [Link]

    public init(
        href: String,
        mediaType: MediaType? = nil,
        templated: Bool = false,
        title: String? = nil,
        rels: [LinkRelation] = [],
        rel: LinkRelation? = nil,
        properties: Properties = Properties(),
        height: Int? = nil,
        width: Int? = nil,
        bitrate: Double? = nil,
        duration: Double? = nil,
        languages: [String] = [],
        alternates: [Link] = [],
        children: [Link] = []
    ) {
        // Convenience to set a single rel during construction.
        var rels = rels
        if let rel = rel {
            rels.append(rel)
        }
        self.href = href
        self.mediaType = mediaType
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

    public init(
        json: Any,
        warnings: WarningLogger? = nil
    ) throws {
        guard let jsonObject = json as? JSONDictionary.Wrapped,
              var href = jsonObject["href"] as? String
        else {
            warnings?.log("`href` is required", model: Self.self, source: json)
            throw JSONError.parsing(Self.self)
        }

        let templated = (jsonObject["templated"] as? Bool) ?? false

        // We support existing publications with incorrect HREFs (not valid percent-encoded
        // URIs). We try to parse them first as valid, but fall back on a percent-decoded
        // path if it fails.
        if !templated, AnyURL(string: href) == nil {
            warnings?.log("`href` is not a valid percent-encoded URL", model: Self.self, source: json)
            guard let url = RelativeURL(path: href) else {
                throw JSONError.parsing(Self.self)
            }
            href = url.string
        }

        self.init(
            href: href,
            mediaType: (jsonObject["type"] as? String).flatMap { MediaType($0) },
            templated: templated,
            title: jsonObject["title"] as? String,
            rels: .init(json: jsonObject["rel"]),
            properties: (try? Properties(json: jsonObject["properties"], warnings: warnings)) ?? Properties(),
            height: parsePositive(jsonObject["height"]),
            width: parsePositive(jsonObject["width"]),
            bitrate: parsePositiveDouble(jsonObject["bitrate"]),
            duration: parsePositiveDouble(jsonObject["duration"]),
            languages: parseArray(jsonObject["language"], allowingSingle: true),
            alternates: .init(json: jsonObject["alternate"], warnings: warnings),
            children: .init(json: jsonObject["children"], warnings: warnings)
        )
    }

    public var json: JSONDictionary.Wrapped {
        makeJSON([
            "href": href,
            "type": encodeIfNotNil(mediaType?.string),
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
            "children": encodeIfNotEmpty(children.json),
        ])
    }

    /// Returns the URL represented by this link's HREF.
    ///
    /// If the HREF is a template, the `parameters` are used to expand it
    /// according to RFC 6570.
    public func url(
        parameters: [String: LosslessStringConvertible] = [:]
    ) -> AnyURL {
        var href = href
        if templated {
            href = URITemplate(href).expand(with: parameters)
        }
        if href.isEmpty {
            href = "#"
        }
        return (AnyURL(string: href) ?? AnyURL(legacyHREF: href))!.normalized
    }

    /// Returns the URL represented by this link's HREF, resolved to the given
    /// `base` URL.
    ///
    /// If the HREF is a template, the `parameters` are used to expand it
    /// according to RFC 6570.
    public func url<T: URLConvertible>(
        relativeTo baseURL: T?,
        parameters: [String: LosslessStringConvertible] = [:]
    ) -> AnyURL {
        let url = url(parameters: parameters)
        return baseURL?.anyURL.resolve(url)?.normalized ?? url
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
    public mutating func expandTemplate(with parameters: [String: LosslessStringConvertible]) {
        guard templated else {
            return
        }
        href = URITemplate(href).expand(with: parameters)
        templated = false
    }

    ///  Merges in the given additional other `properties`.
    public mutating func addProperties(_ properties: JSONDictionary.Wrapped) {
        self.properties.add(properties)
    }
}

public extension Array where Element == Link {
    /// Parses multiple JSON links into an array of Link.
    /// eg. let links = [Link](json: [["href", "http://link1"], ["href", "http://link2"]])
    init(
        json: Any?,
        warnings: WarningLogger? = nil
    ) {
        self.init()
        guard let json = json as? [Any] else {
            return
        }

        let links = json.compactMap { try? Link(json: $0, warnings: warnings) }
        append(contentsOf: links)
    }

    var json: [JSONDictionary.Wrapped] {
        map(\.json)
    }

    /// Finds the first link with the given relation.
    func firstWithRel(_ rel: LinkRelation) -> Link? {
        first { $0.rels.contains(rel) }
    }

    /// Finds all the links with the given relation.
    func filterByRel(_ rel: LinkRelation) -> [Link] {
        filter { $0.rels.contains(rel) }
    }

    /// Finds the first link matching the given HREF.
    func firstWithHREF<T: URLConvertible>(_ href: T) -> Link? {
        let href = href.anyURL.normalized.string
        return first { $0.url().normalized.string == href }
    }

    /// Finds the index of the first link matching the given HREF.
    func firstIndexWithHREF<T: URLConvertible>(_ href: T) -> Int? {
        let href = href.anyURL.normalized.string
        return firstIndex { $0.url().normalized.string == href }
    }

    /// Finds the first link matching the given media type.
    func firstWithMediaType(_ mediaType: MediaType) -> Link? {
        first { mediaType.matches($0.mediaType) }
    }

    /// Finds all the links matching the given media type.
    func filterByMediaType(_ mediaType: MediaType) -> [Link] {
        filter { mediaType.matches($0.mediaType) }
    }

    /// Finds all the links matching any of the given media types.
    func filterByMediaTypes(_ mediaTypes: [MediaType]) -> [Link] {
        filter { link in
            mediaTypes.contains { mediaType in
                mediaType.matches(link.mediaType)
            }
        }
    }

    /// Returns whether all the resources in the collection are bitmaps.
    var allAreBitmap: Bool {
        allSatisfy { $0.mediaType?.isBitmap == true }
    }

    /// Returns whether all the resources in the collection are audio clips.
    var allAreAudio: Bool {
        allSatisfy { $0.mediaType?.isAudio == true }
    }

    /// Returns whether all the resources in the collection are video clips.
    var allAreVideo: Bool {
        allSatisfy { $0.mediaType?.isVideo == true }
    }

    /// Returns whether all the resources in the collection are HTML documents.
    var allAreHTML: Bool {
        allSatisfy { $0.mediaType?.isHTML == true }
    }

    /// Returns whether all the resources in the collection are matching the given media type.
    func allMatchingMediaType(_ mediaType: MediaType) -> Bool {
        allSatisfy { mediaType.matches($0.mediaType) }
    }

    /// Returns whether all the resources in the collection are matching any of the given media types.
    func allMatchingMediaTypes(_ mediaTypes: [MediaType]) -> Bool {
        allSatisfy { link in
            mediaTypes.contains { mediaType in
                mediaType.matches(link.mediaType)
            }
        }
    }
}
