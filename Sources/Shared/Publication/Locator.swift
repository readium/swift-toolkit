//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// https://github.com/readium/architecture/tree/master/locators
public struct Locator: Hashable, CustomStringConvertible, Loggable, Sendable {
    /// The URI of the resource that the Locator Object points to.
    public var href: AnyURL

    /// The media type of the resource that the Locator Object points to.
    public var mediaType: MediaType

    /// The title of the chapter or section which is more relevant in the context of this locator.
    public var title: String?

    /// One or more alternative expressions of the location.
    public var locations: Locations

    /// Textual context of the locator.
    public var text: Text

    public init<T: URLConvertible>(href: T, mediaType: MediaType, title: String? = nil, locations: Locations = .init(), text: Text = .init()) {
        self.href = href.anyURL
        self.mediaType = mediaType
        self.title = title
        self.locations = locations
        self.text = text
    }

    public init?(json: JSONValue?, warnings: WarningLogger? = nil) throws {
        try self.init(json: json, warnings: warnings, legacyHREF: false)
    }

    public init?(json: Any?, warnings: WarningLogger? = nil) throws {
        try self.init(json: JSONValue(json), warnings: warnings)
    }

    public init?(jsonString: String, warnings: WarningLogger? = nil) throws {
        try self.init(jsonString: jsonString, warnings: warnings, legacyHREF: false)
    }

    /// Creates a ``Locator`` from its legacy JSON representation.
    ///
    /// Only use this API when you are upgrading to Readium 3.x and migrating
    /// the ``Locator`` objects stored in your database. See the migration guide
    /// for more information.
    public init?(legacyJSONString: String, warnings: WarningLogger? = nil) throws {
        try self.init(jsonString: legacyJSONString, warnings: warnings, legacyHREF: true)
    }

    private init?(jsonString: String, warnings: WarningLogger?, legacyHREF: Bool) throws {
        let json: JSONValue
        do {
            let any = try JSONSerialization.jsonObject(with: jsonString.data(using: .utf8)!)
            guard let j = JSONValue(any) else {
                throw JSONError.parsing(Self.self)
            }
            json = j
        } catch {
            warnings?.log("Invalid Locator object: \(error)", model: Self.self)
            throw JSONError.parsing(Self.self)
        }

        try self.init(json: json, warnings: warnings, legacyHREF: legacyHREF)
    }

    private init?(json: JSONValue?, warnings: WarningLogger?, legacyHREF: Bool) throws {
        guard let json = json else {
            return nil
        }
        guard let jsonDict = JSONDictionary(json),
              let hrefString = jsonDict.json["href"]?.string,
              let typeString = jsonDict.json["type"]?.string
        else {
            warnings?.log("`href` and `type` required", model: Self.self, source: json.any)
            throw JSONError.parsing(Self.self)
        }

        let jsonObject = jsonDict.json

        guard let type = MediaType(typeString) else {
            warnings?.log("`type` is not a valid media type", model: Self.self, source: json.any)
            throw JSONError.parsing(Self.self)
        }

        guard let href = legacyHREF ? AnyURL(legacyHREF: hrefString) : AnyURL(string: hrefString) else {
            warnings?.log("`href` is not a valid URL", model: Self.self, source: json.any)
            throw JSONError.parsing(Self.self)
        }

        try self.init(
            href: href,
            mediaType: type,
            title: jsonObject["title"]?.string,
            locations: Locations(json: jsonObject["locations"], warnings: warnings),
            text: Text(json: jsonObject["text"], warnings: warnings)
        )
    }

    public var json: JSONDictionary.Wrapped {
        makeJSON([
            "href": .string(href.string),
            "type": .string(mediaType.string),
            "title": encodeIfNotNil(title),
            "locations": encodeIfNotEmpty(locations.json),
            "text": encodeIfNotEmpty(text.json),
        ] as [String: JSONValue])
    }

    public var jsonString: String? {
        serializeJSONString(json)
    }

    public var description: String {
        jsonString ?? "{}"
    }

    /// Makes a copy of the `Locator`, after modifying some of its components.
    public func copy(
        href: AnyURL? = nil,
        mediaType: MediaType? = nil,
        title: String?? = nil,
        locations transformLocations: ((inout Locations) -> Void)? = nil,
        text transformText: ((inout Text) -> Void)? = nil
    ) -> Locator {
        var locations = locations
        var text = text
        transformLocations?(&locations)
        transformText?(&text)
        return Locator(
            href: href ?? self.href,
            mediaType: mediaType ?? self.mediaType,
            title: title ?? self.title,
            locations: locations,
            text: text
        )
    }

    /// Makes a copy of the `Locator`, after modifying some of its components.
    public func copy<T: URLConvertible>(
        href: T?,
        mediaType: MediaType? = nil,
        title: String?? = nil,
        locations: ((inout Locations) -> Void)? = nil,
        text: ((inout Text) -> Void)? = nil
    ) -> Locator {
        copy(
            href: href?.anyURL,
            mediaType: mediaType,
            title: title,
            locations: locations,
            text: text
        )
    }

    /// One or more alternative expressions of the location.
    /// https://github.com/readium/architecture/tree/master/models/locators#the-location-object
    ///
    /// Properties are mutable for convenience when making a copy, but the `locations` property
    /// is immutable in `Locator`, for safety.
    public struct Locations: Hashable, Loggable, WarningLogger, Sendable {
        /// Contains one or more fragment in the resource referenced by the `Locator`.
        public var fragments: [String]
        /// Progression in the resource expressed as a percentage (between 0 and 1).
        public var progression: Double?
        /// Progression in the publication expressed as a percentage (between 0 and 1).
        public var totalProgression: Double?
        /// An index in the publication (>= 1).
        public var position: Int?

        /// Additional locations for extensions.
        public var otherLocations: JSONDictionary.Wrapped {
            get { otherLocationsJSON.json }
            set { otherLocationsJSON = JSONDictionary(newValue) ?? JSONDictionary() }
        }

        /// Trick to keep the struct equatable despite [String: Any]
        private var otherLocationsJSON: JSONDictionary

        public init(fragments: [String] = [], progression: Double? = nil, totalProgression: Double? = nil, position: Int? = nil, otherLocations: JSONDictionary.Wrapped = [:]) {
            self.fragments = fragments
            self.progression = progression
            self.totalProgression = totalProgression
            self.position = position
            otherLocationsJSON = JSONDictionary(otherLocations) ?? JSONDictionary()
        }

        public init(json: JSONValue?, warnings: WarningLogger? = nil) throws {
            if json == nil {
                self.init()
                return
            }
            guard var jsonObject = JSONDictionary(json) else {
                warnings?.log("Invalid Locations object", model: Self.self, source: json?.any)
                throw JSONError.parsing(Self.self)
            }
            var fragments = parseArray(jsonObject.pop("fragments")) as [String]
            if let fragment = jsonObject.pop("fragment")?.string {
                fragments.append(fragment)
            }
            self.init(
                fragments: fragments,
                progression: parseDouble(jsonObject.pop("progression")),
                totalProgression: parseDouble(jsonObject.pop("totalProgression")),
                position: parsePositive(jsonObject.pop("position")),
                otherLocations: jsonObject.json
            )
        }

        public init(json: Any?, warnings: WarningLogger? = nil) throws {
            try self.init(json: JSONValue(json), warnings: warnings)
        }

        public init(jsonString: String, warnings: WarningLogger? = nil) {
            do {
                let any = try JSONSerialization.jsonObject(with: jsonString.data(using: .utf8)!)
                try self.init(json: JSONValue(any), warnings: warnings)
            } catch {
                warnings?.log("Invalid Locations object: \(error)", model: Self.self)
                self.init()
            }
        }

        public var isEmpty: Bool {
            json.isEmpty
        }

        public var json: JSONDictionary.Wrapped {
            makeJSON([
                "fragments": encodeIfNotEmpty(fragments),
                "progression": encodeIfNotNil(progression),
                "totalProgression": encodeIfNotNil(totalProgression),
                "position": encodeIfNotNil(position),
            ] as [String: JSONValue], additional: otherLocations)
        }

        public var jsonString: String? {
            serializeJSONString(json)
        }

        /// Syntactic sugar to access the `otherLocations` values by subscripting `Locations` directly.
        /// locations["cssSelector"] == locations.otherLocations["cssSelector"]
        public subscript(key: String) -> JSONValue? {
            otherLocations[key]
        }
    }

    public struct Text: Hashable, Loggable, Sendable {
        public var after: String?
        public var before: String?
        public var highlight: String?

        public init(after: String? = nil, before: String? = nil, highlight: String? = nil) {
            self.after = after
            self.before = before
            self.highlight = highlight
        }

        public init(json: JSONValue?, warnings: WarningLogger? = nil) throws {
            if json == nil {
                self.init()
                return
            }
            guard let jsonDict = JSONDictionary(json) else {
                warnings?.log("Invalid Text object", model: Self.self, source: json?.any)
                throw JSONError.parsing(Self.self)
            }
            let jsonObject = jsonDict.json
            self.init(
                after: jsonObject["after"]?.string,
                before: jsonObject["before"]?.string,
                highlight: jsonObject["highlight"]?.string
            )
        }

        public init(json: Any?, warnings: WarningLogger? = nil) throws {
            try self.init(json: JSONValue(json), warnings: warnings)
        }

        public init(jsonString: String, warnings: WarningLogger? = nil) {
            do {
                let any = try JSONSerialization.jsonObject(with: jsonString.data(using: .utf8)!)
                try self.init(json: JSONValue(any), warnings: warnings)
            } catch {
                warnings?.log("Invalid Text object", model: Self.self)
                self.init()
            }
        }

        public var json: JSONDictionary.Wrapped {
            makeJSON([
                "after": encodeIfNotNil(after),
                "before": encodeIfNotNil(before),
                "highlight": encodeIfNotNil(highlight),
            ] as [String: JSONValue])
        }

        public var jsonString: String? {
            serializeJSONString(json)
        }

        /// Returns a copy of this text after sanitizing its content for user display.
        public func sanitized() -> Locator.Text {
            Locator.Text(
                after: after?.coalescingWhitespaces().removingSuffix(" "),
                before: before?.coalescingWhitespaces().removingPrefix(" "),
                highlight: highlight?.coalescingWhitespaces()
            )
        }

        /// Returns a copy of this text after highlighting a sub-range in the `highlight` property.
        ///
        /// The bounds of the range must be valid indices of the `highlight` property.
        public subscript(range: Range<String.Index>) -> Text {
            guard
                let highlight = highlight,
                !highlight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                return Locator.Text(
                    after: after.takeIf { !$0.isEmpty },
                    before: before.takeIf { !$0.isEmpty },
                    highlight: nil
                )
            }

            let range = range
                .clamped(to: highlight.startIndex ..< highlight.endIndex)

            var before = before ?? ""
            var after = after ?? ""
            let newHighlight = highlight[range]
            before = before + highlight[..<range.lowerBound]
            after = highlight[range.upperBound...] + after

            return Locator.Text(
                after: Optional(after).takeIf { !$0.isEmpty },
                before: Optional(before).takeIf { !$0.isEmpty },
                highlight: String(newHighlight)
            )
        }
    }
}

public extension Array where Element == Locator {
    /// Parses multiple JSON locators into an array of `Locator`.
    init(json: JSONValue?, warnings: WarningLogger? = nil) {
        self.init()
        guard let json = json else {
            return
        }

        switch json {
        case let .array(array):
            let links = array.compactMap { try? Locator(json: $0, warnings: warnings) }
            append(contentsOf: links)
        default:
            break
        }
    }

    init(json: Any?, warnings: WarningLogger? = nil) {
        self.init(json: JSONValue(json), warnings: warnings)
    }

    var json: [JSONDictionary.Wrapped] {
        map(\.json)
    }
}

/// Represents a sequential list of `Locator` objects.
///
/// For example, a search result or a list of positions.
public struct LocatorCollection: Hashable {
    public var metadata: Metadata
    public var links: [Link]
    public var locators: [Locator]

    public init(metadata: Metadata = Metadata(), links: [Link] = [], locators: [Locator] = []) {
        self.metadata = metadata
        self.links = links
        self.locators = locators
    }

    public init?(json: JSONValue?, warnings: WarningLogger? = nil) {
        guard let json = json else {
            return nil
        }
        guard let jsonDict = JSONDictionary(json) else {
            warnings?.log("Not a JSON object", model: Self.self, source: json.any)
            return nil
        }
        let jsonObject = jsonDict.json
        self.init(
            metadata: Metadata(json: jsonObject["metadata"], warnings: warnings),
            links: [Link](json: jsonObject["links"]),
            locators: [Locator](json: jsonObject["locators"])
        )
    }

    public init?(json: Any?, warnings: WarningLogger? = nil) {
        self.init(json: JSONValue(json), warnings: warnings)
    }

    public var json: JSONDictionary.Wrapped {
        makeJSON([
            "metadata": encodeIfNotEmpty(metadata.json),
            "links": encodeIfNotEmpty(links.json),
            "locators": encodeIfNotEmpty(locators.json), // Updated to encodeIfNotEmpty
        ] as [String: JSONValue])
    }

    /// Holds the metadata of a `LocatorCollection`.
    public struct Metadata: Hashable {
        public var localizedTitle: LocalizedString?
        public var title: String? {
            localizedTitle?.string
        }

        /// Indicates the total number of locators in the collection.
        public var numberOfItems: Int?

        /// Additional properties for extensions.
        public var otherMetadata: JSONDictionary.Wrapped {
            get { otherMetadataJSON.json }
            set { otherMetadataJSON = JSONDictionary(newValue) ?? JSONDictionary() }
        }

        /// Trick to keep the struct equatable despite [String: Any]
        private var otherMetadataJSON: JSONDictionary

        public init(
            title: LocalizedStringConvertible? = nil,
            numberOfItems: Int? = nil,
            otherMetadata: JSONDictionary.Wrapped = [:]
        ) {
            localizedTitle = title?.localizedString
            self.numberOfItems = numberOfItems
            otherMetadataJSON = JSONDictionary(otherMetadata) ?? JSONDictionary()
        }

        public init(json: JSONValue?, warnings: WarningLogger? = nil) {
            if var json = JSONDictionary(json) {
                localizedTitle = try? LocalizedString(json: json.pop("title"), warnings: warnings)
                numberOfItems = parsePositive(json.pop("numberOfItems"))
                otherMetadataJSON = json
            } else {
                warnings?.log("Not a JSON object", model: Self.self, source: json?.any)
                localizedTitle = nil
                numberOfItems = nil
                otherMetadataJSON = JSONDictionary()
            }
        }

        public init(json: Any?, warnings: WarningLogger? = nil) {
            self.init(json: JSONValue(json), warnings: warnings)
        }

        public var json: JSONDictionary.Wrapped {
            makeJSON([
                "title": encodeIfNotNil(localizedTitle?.json),
                "numberOfItems": encodeIfNotNil(numberOfItems),
            ] as [String: JSONValue], additional: otherMetadata)
        }
    }
}
