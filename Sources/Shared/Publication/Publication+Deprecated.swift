//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

@available(*, unavailable, renamed: "Publication")
public typealias WebPublication = Publication

public extension Publication {
    @available(*, deprecated, message: "format and formatVersion are deprecated", renamed: "init(manifest:fetcher:servicesBuilder:)")
    convenience init(manifest: Manifest, fetcher: Fetcher = EmptyFetcher(), servicesBuilder: PublicationServicesBuilder = .init(), format: Format = .unknown, formatVersion: String? = nil) {
        self.init(manifest: manifest, fetcher: fetcher, servicesBuilder: servicesBuilder)
        self.format = format
        self.formatVersion = formatVersion
    }

    @available(*, unavailable, renamed: "init(manifest:)")
    convenience init() {
        self.init(manifest: Manifest(metadata: Metadata(title: "")))
    }

    @available(*, unavailable, renamed: "init(format:formatVersion:manifest:)")
    convenience init(format: Format = .unknown, formatVersion: String? = nil, positionListFactory: @escaping (Publication) -> [Locator] = { _ in [] }, context: [String] = [], metadata: Metadata, links: [Link] = [], readingOrder: [Link] = [], resources: [Link] = [], tableOfContents: [Link] = [], otherCollections: [String: [PublicationCollection]] = [:]) {
        self.init(
            manifest: Manifest(context: context, metadata: metadata, links: links, readingOrder: readingOrder, resources: resources, tableOfContents: tableOfContents, subcollections: otherCollections)
        )
    }

    @available(*, unavailable, message: "Custom HREF normalization is not supported anymore", renamed: "init(json:)")
    convenience init(json: Any, warnings: WarningLogger? = nil, normalizeHref: (String) -> String = { $0 }) throws {
        fatalError("Not available.")
    }

    @available(*, unavailable, renamed: "formatVersion")
    var version: Double { 0 }

    /// Factory used to build lazily the `positionList`.
    /// By default, a parser will set this to parse the `positionList` from the publication. But the host app might want to overwrite this with a custom closure to implement for example a cache mechanism.
    @available(*, unavailable, message: "Implement `PositionsService` instead")
    var positionListFactory: (Publication) -> [Locator] { { _ in [] } }

    @available(*, unavailable, renamed: "baseURL")
    var baseUrl: URL? { baseURL }

    @available(*, unavailable, message: "This is not used anymore, don't set it")
    var updatedDate: Date { Date() }

    @available(*, unavailable, message: "Check the publication's type using `conforms(to:)` instead")
    var internalData: [String: String] { [:] }

    @available(*, unavailable, renamed: "json")
    var manifestCanonical: String { jsonManifest ?? "" }

    @available(*, unavailable, renamed: "init(json:)")
    static func parse(pubDict: [String: Any]) throws -> Publication {
        fatalError("Not available")
    }

    @available(*, unavailable, renamed: "positions")
    var positionList: [Locator] { positions }

    @available(*, unavailable, renamed: "positionsByResource")
    var positionListByResource: [String: [Locator]] { [:] }

    @available(*, unavailable, renamed: "subcollections")
    var otherCollections: [String: [PublicationCollection]] { subcollections }

    @available(*, unavailable, renamed: "link(withHREF:)")
    func resource(withRelativePath path: String) -> Link? {
        link(withHREF: path)
    }

    @available(*, unavailable, renamed: "link(withHREF:)")
    func resource(withHref href: String) -> Link? {
        link(withHREF: href)
    }

    @available(*, unavailable, message: "Use `setSelfLink` instead")
    func addSelfLink(endpoint: String, for baseURL: URL) {
        let manifestURL = baseURL.appendingPathComponent("\(endpoint)/manifest.json")
        setSelfLink(href: manifestURL.absoluteString)
    }

    @available(*, unavailable, message: "`Publication` is now immutable")
    internal func setCollectionLinks(_ links: [Link], forRole role: String) {}

    @available(*, unavailable, renamed: "link(withHREF:)")
    func link(withHref href: String) -> Link? {
        link(withHREF: href)
    }

    @available(*, unavailable, message: "This will be removed in a future version")
    func link(where predicate: (Link) -> Bool) -> Link? {
        (resources + readingOrder + links).first(where: predicate)
    }

    @available(*, unavailable, message: "Use `link.url(relativeTo: publication.baseURL)` instead")
    func uriTo(link: Link?) -> URL? {
        link?.url(relativeTo: baseURL)
    }

    @available(*, unavailable, message: "Use `link.url(relativeTo: publication.baseURL)` instead")
    func url(to link: Link?) -> URL? {
        link?.url(relativeTo: baseURL)
    }

    @available(*, unavailable, message: "Use `link.url(relativeTo: publication.baseURL)` instead")
    func url(to href: String?) -> URL? {
        href.flatMap { link(withHREF: $0)?.url(relativeTo: baseURL) }
    }

    @available(*, unavailable, message: "Use `cover` to get the `UIImage` directly, or `link(withRel: \"cover\")` if you really want the cover link", renamed: "cover")
    var coverLink: Link? { link(withRel: .cover) }

    @available(*, unavailable, message: "Use `metadata.effectiveReadingProgression` instead", renamed: "metadata.effectiveReadingProgression")
    var contentLayout: ReadingProgression { metadata.effectiveReadingProgression }

    @available(*, unavailable, message: "Use `metadata.effectiveReadingProgression` instead", renamed: "metadata.effectiveReadingProgression")
    func contentLayout(forLanguage language: String?) -> ReadingProgression { metadata.effectiveReadingProgression }
}

public extension Publication {
    @available(*, unavailable, renamed: "listOfAudioClips")
    var listOfAudioFiles: [Link] { listOfAudioClips }

    @available(*, unavailable, renamed: "listOfVideoClips")
    var listOfVideos: [Link] { listOfVideoClips }
}

@available(*, unavailable, renamed: "LocalizedString")
public typealias MultilangString = LocalizedString

public extension LocalizedString {
    @available(*, unavailable, message: "Get with the property `string`")
    var singleString: String? {
        string.isEmpty ? nil : string
    }

    @available(*, unavailable, message: "Get with `string(forLanguageCode:)`")
    var multiString: [String: String] {
        guard case let .localized(strings) = self else {
            return [:]
        }
        return strings
    }

    @available(*, unavailable, renamed: "LocalizedString.localized")
    init() {
        self = .localized([:])
    }
}

public extension Metadata {
    @available(*, unavailable, renamed: "type")
    var rdfType: String? { type }

    @available(*, unavailable, renamed: "localizedTitle")
    var multilangTitle: LocalizedString { localizedTitle }

    @available(*, unavailable, renamed: "localizedSubtitle")
    var multilangSubtitle: LocalizedString? { localizedSubtitle }

    @available(*, unavailable, message: "Not used anymore, you can store the rights in `otherMetadata[\"rights\"]` if necessary")
    var rights: String? { nil }

    @available(*, unavailable, message: "Not used anymore, you can store the source in `otherMetadata[\"source\"]` if necessary")
    var source: String? { nil }

    @available(*, unavailable, renamed: "init(title:)")
    init() {
        self.init(title: "")
    }

    @available(*, unavailable, message: "Use `localizedTitle.string(forLanguageCode:)` instead")
    func titleForLang(_ lang: String) -> String? {
        localizedTitle.string(forLanguageCode: lang)
    }

    @available(*, unavailable, message: "Use `localizedSubtitle.string(forLanguageCode:)` instead")
    func subtitleForLang(_ lang: String) -> String? {
        localizedSubtitle?.string(forLanguageCode: lang)
    }

    @available(*, unavailable, renamed: "init(json:)")
    static func parse(metadataDict: [String: Any]) throws -> Metadata {
        try Metadata(json: metadataDict, normalizeHREF: { $0 })
    }

    @available(*, unavailable, renamed: "presentation")
    var rendition: EPUBRendition { presentation }

    @available(*, unavailable, message: "Use `effectiveReadingProgression` instead", renamed: "effectiveReadingProgression")
    var contentLayout: ReadingProgression { effectiveReadingProgression }

    @available(*, unavailable, message: "Use `effectiveReadingProgression` instead", renamed: "effectiveReadingProgression")
    func contentLayout(forLanguage language: String?) -> ReadingProgression { effectiveReadingProgression }
}

public extension PublicationCollection {
    @available(*, unavailable, renamed: "subcollections")
    var otherCollections: [String: [PublicationCollection]] { subcollections }
}

public extension Contributor {
    @available(*, unavailable, renamed: "localizedName")
    var multilangName: LocalizedString { localizedName }

    @available(*, unavailable, renamed: "init(name:)")
    init() {
        self.init(name: "")
    }

    @available(*, unavailable, renamed: "init(json:)")
    static func parse(_ cDict: [String: Any]) throws -> Contributor {
        fatalError()
    }

    @available(*, unavailable, message: "Use `[Contributor](json:)` instead")
    static func parse(contributors: Any) throws -> [Contributor] {
        fatalError()
    }
}

public extension Subject {
    @available(*, unavailable, renamed: "init(name:)")
    init() {
        self.init(name: "")
    }
}

public extension Link {
    @available(*, unavailable, renamed: "type")
    var typeLink: String? { type }

    @available(*, unavailable, renamed: "rels")
    var rel: [String] { rels.map(\.string) }

    @available(*, unavailable, renamed: "href")
    var absoluteHref: String? { href }

    @available(*, unavailable, renamed: "init(href:)")
    init() {
        self.init(href: "")
    }

    @available(*, unavailable, renamed: "init(json:warnings:normalizeHREF:)")
    init(json: Any, warnings: WarningLogger? = nil, normalizeHref: (String) -> String) throws {
        try self.init(json: json, warnings: warnings, normalizeHREF: normalizeHref)
    }

    @available(*, unavailable, renamed: "init(json:)")
    static func parse(linkDict: [String: Any]) throws -> Link {
        fatalError()
    }

    @available(*, unavailable, message: "The media overlay API was only half implemented and will be refactored later")
    var mediaOverlays: MediaOverlays { MediaOverlays() }
}

public extension Array where Element == Link {
    @available(*, unavailable, renamed: "init(json:warnings:normalizeHREF:)")
    init(json: Any?, warnings: WarningLogger? = nil, normalizeHref: (String) -> String) {
        self.init(json: json, warnings: warnings, normalizeHREF: normalizeHref)
    }
}

public extension Properties {
    @available(*, unavailable, renamed: "Presentation.Orientation")
    typealias Orientation = Presentation.Orientation

    @available(*, unavailable, renamed: "Presentation.Page")
    typealias Page = Presentation.Page

    @available(*, unavailable, renamed: "indirectAcquisitions")
    var indirectAcquisition: [OPDSAcquisition] {
        indirectAcquisitions
    }

    @available(*, unavailable, message: "The media overlay API was only half implemented and will be refactored later")
    var mediaOverlay: String? { nil }

    @available(*, unavailable, message: "`Properties` is now immutable")
    internal mutating func setProperty<T: RawRepresentable>(_ value: T?, forKey key: String) {}

    @available(*, unavailable, message: "`Properties` is now immutable")
    internal mutating func setProperty<T: Collection>(_ value: T?, forKey key: String) {}
}

public extension Presentation {
    @available(*, unavailable, renamed: "EPUBLayout")
    typealias Layout = EPUBLayout
}

@available(*, unavailable, renamed: "OPDSPrice")
public typealias Price = OPDSPrice

@available(*, unavailable, renamed: "OPDSAcquisition")
public typealias IndirectAcquisition = OPDSAcquisition

public extension OPDSAcquisition {
    @available(*, unavailable, renamed: "type")
    var typeAcquisition: String { type }

    @available(*, unavailable, renamed: "children")
    var child: [OPDSAcquisition] { children }
}

@available(*, unavailable, renamed: "ContentLayout")
public typealias ContentLayoutStyle = ContentLayout

@available(*, unavailable, renamed: "Presentation")
public typealias EPUBRendition = Presentation

@available(*, unavailable, renamed: "Encryption")
public typealias EPUBEncryption = Encryption

@available(*, unavailable, renamed: "Locator.Locations")
public typealias Locations = Locator.Locations

@available(*, unavailable, renamed: "Locator.Text")
public typealias LocatorText = Locator.Text

@available(*, unavailable, message: "Use your own Bookmark model in your app, this one is not used by Readium 2 anymore")
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

    public var resourceHref: String { locator.href }
    public var resourceType: String { locator.type }
    public var resourceTitle: String { locator.title ?? "" }
    public var location: Locations { locator.locations }
    public var locations: Locations? { locator.locations }
    public var locatorText: LocatorText { locator.text }
}
