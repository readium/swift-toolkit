//
//  Publication+Deprecated.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 13.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

@available(*, deprecated, renamed: "Publication")
public typealias WebPublication = Publication

extension Publication {
    
    @available(*, deprecated, renamed: "init(manifest:)")
    public convenience init() {
        self.init(manifest: Manifest(metadata: Metadata(title: "")))
    }
    
    @available(*, deprecated, renamed: "init(format:formatVersion:manifest:)")
    public convenience init(format: Format = .unknown, formatVersion: String? = nil, positionListFactory: @escaping (Publication) -> [Locator] = { _ in [] }, context: [String] = [], metadata: Metadata, links: [Link] = [], readingOrder: [Link] = [], resources: [Link] = [], tableOfContents: [Link] = [], otherCollections: [String: [PublicationCollection]] = [:]) {
        self.init(
            manifest: Manifest(context: context, metadata: metadata, links: links, readingOrder: readingOrder, resources: resources, tableOfContents: tableOfContents, subcollections: otherCollections),
            format: format,
            formatVersion: formatVersion
        )
    }
    
    @available(*, unavailable, message: "Custom HREF normalization is not supported anymore", renamed: "init(json:)")
    public convenience init(json: Any, warnings: WarningLogger? = nil, normalizeHref: (String) -> String = { $0 }) throws {
        fatalError("Not available.")
    }
    
    @available(*, deprecated, renamed: "formatVersion")
    public var version: Double {
        guard let versionString = formatVersion,
            let version = Double(versionString) else
        {
            return 0
        }
        return version
    }

    /// Factory used to build lazily the `positionList`.
    /// By default, a parser will set this to parse the `positionList` from the publication. But the host app might want to overwrite this with a custom closure to implement for example a cache mechanism.
    @available(*, unavailable, message: "Implement `PositionsService` instead")
    public var positionListFactory: (Publication) -> [Locator] { { _ in [] } }
    
    @available(*, deprecated, renamed: "baseURL")
    public var baseUrl: URL? { return baseURL }
    
    @available(*, unavailable, message: "This is not used anymore, don't set it")
    public var updatedDate: Date { Date() }
    
    @available(*, deprecated, message: "Check the publication's type using `format` instead")
    public var internalData: [String: String] {
        // The code in the testapp used to check a property in `publication.internalData["type"]` to know which kind of publication this is.
        // To avoid breaking any app, we reproduce this value here:
        return [
            "type": {
                switch format {
                case .epub:
                    return "epub"
                case .cbz:
                    return "cbz"
                case .pdf:
                    return "pdf"
                default:
                    return "unknown"
                }
            }()
        ]
    }
    
    @available(*, unavailable, renamed: "json")
    public var manifestCanonical: String { jsonManifest ?? "" }
    
    @available(*, unavailable, renamed: "init(json:)")
    public static func parse(pubDict: [String: Any]) throws -> Publication {
        fatalError("Not available")
    }

    @available(*, deprecated, renamed: "positions")
    public var positionList: [Locator] { positions }
    
    @available(*, deprecated, renamed: "positionsByResource")
    public var positionListByResource: [String: [Locator]] { positionsByResource }
    
    @available(*, deprecated, renamed: "subcollections")
    public var otherCollections: [String: [PublicationCollection]] { subcollections }
    
    @available(*, deprecated, renamed: "link(withHREF:)")
    public func resource(withRelativePath path: String) -> Link? {
        return link(withHREF: path)
    }
    
    @available(*, deprecated, renamed: "link(withHREF:)")
    public func resource(withHref href: String) -> Link? {
        return link(withHREF: href)
    }
    
    @available(*, deprecated, message: "Use `setSelfLink` instead")
    public func addSelfLink(endpoint: String, for baseURL: URL) {
        let manifestURL = baseURL.appendingPathComponent("\(endpoint)/manifest.json")
        setSelfLink(href: manifestURL.absoluteString)
    }
    
    @available(*, unavailable, message: "`Publication` is now immutable")
    func setCollectionLinks(_ links: [Link], forRole role: String) {}
    
    @available(*, deprecated, renamed: "link(withHREF:)")
    public func link(withHref href: String) -> Link? {
        return link(withHREF: href)
    }
    
    @available(*, deprecated, message: "This will be removed in a future version")
    public func link(where predicate: (Link) -> Bool) -> Link? {
        return (resources + readingOrder + links).first(where: predicate)
    }
    
    @available(*, unavailable, message: "Use `link.url(relativeTo: publication.baseURL)` instead")
    public func uriTo(link: Link?) -> URL? {
        return link?.url(relativeTo: baseURL)
    }
    
    @available(*, deprecated, message: "Use `link.url(relativeTo: publication.baseURL)` instead")
    public func url(to link: Link?) -> URL? {
        return link?.url(relativeTo: baseURL)
    }
    
    @available(*, deprecated, message: "Use `link.url(relativeTo: publication.baseURL)` instead")
    public func url(to href: String?) -> URL? {
        return href.flatMap { link(withHREF: $0)?.url(relativeTo: baseURL) }
    }

    @available(*, deprecated, message: "Use `cover` to get the `UIImage` directly, or `link(withRel: \"cover\")` if you really want the cover link", renamed: "cover")
    public var coverLink: Link? { link(withRel: .cover) }
    
    @available(*, unavailable, message: "Use `metadata.effectiveReadingProgression` instead", renamed: "metadata.effectiveReadingProgression")
    public var contentLayout: ReadingProgression { metadata.effectiveReadingProgression }
    
    @available(*, unavailable, message: "Use `metadata.effectiveReadingProgression` instead", renamed: "metadata.effectiveReadingProgression")
    public func contentLayout(forLanguage language: String?) -> ReadingProgression { metadata.effectiveReadingProgression }

}

extension Publication {
    
    @available(*, deprecated, renamed: "listOfAudioClips")
    public var listOfAudioFiles: [Link] { listOfAudioClips }
    
    @available(*, deprecated, renamed: "listOfVideoClips")
    public var listOfVideos: [Link] { listOfVideoClips }
    
}

@available(*, deprecated, renamed: "LocalizedString")
public typealias MultilangString = LocalizedString

extension LocalizedString {
    
    @available(*, deprecated, message: "Get with the property `string`")
    public var singleString: String? {
        string.isEmpty ? nil : string
    }
    
    @available(*, deprecated, message: "Get with `string(forLanguageCode:)`")
    public var multiString: [String: String] {
        guard case .localized(let strings) = self else {
            return [:]
        }
        return strings
    }
    
    @available(*, deprecated, renamed: "LocalizedString.localized")
    public init() {
        self = .localized([:])
    }

}

extension Metadata {
    
    @available(*, deprecated, renamed: "type")
    public var rdfType: String? { type }

    @available(*, deprecated, renamed: "localizedTitle")
    public var multilangTitle: LocalizedString { localizedTitle }

    @available(*, deprecated, renamed: "localizedSubtitle")
    public var multilangSubtitle: LocalizedString? { localizedSubtitle }

    @available(*, unavailable, message: "Not used anymore, you can store the rights in `otherMetadata[\"rights\"]` if necessary")
    public var rights: String? { nil }
    
    @available(*, unavailable, message: "Not used anymore, you can store the source in `otherMetadata[\"source\"]` if necessary")
    public var source: String? { nil }
    
    @available(*, deprecated, renamed: "init(title:)")
    public init() {
        self.init(title: "")
    }
    
    @available(*, deprecated, message: "Use `localizedTitle.string(forLanguageCode:)` instead")
    public func titleForLang(_ lang: String) -> String? {
        return localizedTitle.string(forLanguageCode: lang)
    }
    
    @available(*, deprecated, message: "Use `localizedSubtitle.string(forLanguageCode:)` instead")
    public func subtitleForLang(_ lang: String) -> String? {
        return localizedSubtitle?.string(forLanguageCode: lang)
    }
    
    @available(*, deprecated, renamed: "init(json:)")
    public static func parse(metadataDict: [String: Any]) throws -> Metadata {
        return try Metadata(json: metadataDict, normalizeHREF: { $0 })
    }
    
    @available(*, deprecated, renamed: "presentation")
    public var rendition: EPUBRendition { presentation }

    @available(*, unavailable, message: "Use `effectiveReadingProgression` instead", renamed: "effectiveReadingProgression")
    public var contentLayout: ReadingProgression { effectiveReadingProgression }

    @available(*, unavailable, message: "Use `effectiveReadingProgression` instead", renamed: "effectiveReadingProgression")
    public func contentLayout(forLanguage language: String?) -> ReadingProgression { effectiveReadingProgression }

}

extension PublicationCollection {
    
    @available(*, deprecated, renamed: "subcollections")
    public var otherCollections: [String: [PublicationCollection]] { subcollections }
    
}

extension Contributor {
    
    @available(*, deprecated, renamed: "localizedName")
    public var multilangName: LocalizedString { localizedName }

    @available(*, deprecated, renamed: "init(name:)")
    public init() {
        self.init(name: "")
    }
    
    @available(*, unavailable, renamed: "init(json:)")
    public static func parse(_ cDict: [String: Any]) throws -> Contributor {
        fatalError()
    }
    
    @available(*, unavailable, message: "Use `[Contributor](json:)` instead")
    public static func parse(contributors: Any) throws -> [Contributor] {
        fatalError()
    }
    
}

extension Subject {
    
    @available(*, deprecated, renamed: "init(name:)")
    public init() {
        self.init(name: "")
    }
    
}

extension Link {
    
    @available(*, deprecated, renamed: "type")
    public var typeLink: String? { type }
    
    @available(*, deprecated, renamed: "rels")
    public var rel: [String] { rels.map { $0.string } }
    
    @available(*, deprecated, renamed: "href")
    public var absoluteHref: String? { href }
    
    @available(*, deprecated, renamed: "init(href:)")
    public init() {
        self.init(href: "")
    }
    
    @available(*, deprecated, renamed: "init(json:warnings:normalizeHREF:)")
    public init(json: Any, warnings: WarningLogger? = nil, normalizeHref: (String) -> String) throws {
        try self.init(json: json, warnings: warnings, normalizeHREF: normalizeHref)
    }
    
    
    @available(*, unavailable, renamed: "init(json:)")
    static public func parse(linkDict: [String: Any]) throws -> Link {
        fatalError()
    }
    
    @available(*, unavailable, message: "The media overlay API was only half implemented and will be refactored later")
    public var mediaOverlays: MediaOverlays { MediaOverlays() }
    
}

extension Array where Element == Link {
    
    @available(*, deprecated, renamed: "init(json:warnings:normalizeHREF:)")
    public init(json: Any?, warnings: WarningLogger? = nil, normalizeHref: (String) -> String) {
        self.init(json: json, warnings: warnings, normalizeHREF: normalizeHref)
    }
        
}

extension Properties {

    @available(*, deprecated, renamed: "Presentation.Orientation")
    public typealias Orientation = Presentation.Orientation
    
    @available(*, deprecated, renamed: "Presentation.Page")
    public typealias Page = Presentation.Page
    
    @available(*, deprecated, renamed: "indirectAcquisitions")
    public var indirectAcquisition: [OPDSAcquisition] {
        indirectAcquisitions
    }
    
    @available(*, unavailable, message: "The media overlay API was only half implemented and will be refactored later")
    public var mediaOverlay: String? { nil }
    
    @available(*, unavailable, message: "`Properties` is now immutable")
    mutating func setProperty<T: RawRepresentable>(_ value: T?, forKey key: String) {}
    
    @available(*, unavailable, message: "`Properties` is now immutable")
    mutating func setProperty<T: Collection>(_ value: T?, forKey key: String) {}

}

extension Presentation {
    
    @available(*, deprecated, renamed: "EPUBLayout")
    public typealias Layout = EPUBLayout
    
}

@available(*, deprecated, renamed: "OPDSPrice")
public typealias Price = OPDSPrice

@available(*, deprecated, renamed: "OPDSAcquisition")
public typealias IndirectAcquisition = OPDSAcquisition

extension OPDSAcquisition {

    @available(*, deprecated, renamed: "type")
    public var typeAcquisition: String { type }
    
    @available(*, deprecated, renamed: "children")
    public var child: [OPDSAcquisition] { children }
    
}

@available(*, deprecated, renamed: "ContentLayout")
public typealias ContentLayoutStyle = ContentLayout

@available(*, deprecated, renamed: "Presentation")
public typealias EPUBRendition = Presentation

@available(*, deprecated, renamed: "Encryption")
public typealias EPUBEncryption = Encryption

@available(*, deprecated, renamed: "Locator.Locations")
public typealias Locations = Locator.Locations

@available(*, deprecated, renamed: "Locator.Text")
public typealias LocatorText = Locator.Text

@available(*, deprecated, message: "Use your own Bookmark model in your app, this one is not used by Readium 2 anymore")
public class Bookmark {
    public var id: Int64?
    public var bookID: Int = 0
    public var publicationID: String
    public var resourceIndex: Int
    public var locator: Locator
    public var creationDate: Date
    
    public init(id: Int64? = nil, publicationID: String, resourceIndex: Int, locator: Locator, creationDate: Date = Date()) {
        self.id = id
        self.publicationID = publicationID
        self.resourceIndex = resourceIndex
        self.locator = locator
        self.creationDate = creationDate
    }
    
    public convenience init(bookID: Int, publicationID: String, resourceIndex: Int, resourceHref: String, resourceType: String, resourceTitle: String, location: Locations, locatorText: LocatorText, creationDate: Date = Date(), id: Int64? = nil) {
        self.init(
            id: id,
            publicationID: publicationID,
            resourceIndex: resourceIndex,
            locator: Locator(
                href: resourceHref,
                type: resourceType,
                title: resourceTitle,
                locations: location,
                text: locatorText
            ),
            creationDate: creationDate
        )
    }
    
    public var resourceHref: String { return locator.href }
    public var resourceType: String { return locator.type }
    public var resourceTitle: String { return locator.title ?? "" }
    public var location: Locations { return locator.locations }
    public var locations: Locations? { return locator.locations }
    public var locatorText: LocatorText { return locator.text }
    
}
