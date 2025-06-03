//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Link relations as defined in https://readium.org/webpub-manifest/relationships.html
public struct LinkRelation: Sendable {
    /// The string representation of this link relation.
    public let string: String

    public init(_ string: String) {
        // > Registered relation type names MUST conform to the reg-rel-type rule
        // > (see Section 3.3) and MUST be compared character by character in a
        // > case-insensitive fashion.
        // https://tools.ietf.org/html/rfc8288#section-2.1.1
        self.string = string.lowercased()
    }

    public func hasPrefix(_ prefix: String) -> Bool {
        string.hasPrefix(prefix.lowercased())
    }

    public var isSample: Bool {
        self == .preview || self == .opdsAcquisitionSample
    }

    public var isImage: Bool {
        hasPrefix("http://opds-spec.org/image")
    }

    public var isOPDSAcquisition: Bool {
        hasPrefix("http://opds-spec.org/acquisition")
    }

    // MARK: - Known Link Relations

    /// Designates a substitute for the link's context.
    public static let alternate = LinkRelation("alternate")
    /// Refers to a table of contents.
    public static let contents = LinkRelation("contents")
    /// Refers to a publication's cover.
    public static let cover = LinkRelation("cover")
    /// Links to a manifest.
    public static let manifest = LinkRelation("manifest")
    /// Refers to a URI or templated URI that will perform a search.
    public static let search = LinkRelation("search")
    /// Conveys an identifier for the link's context.
    public static let `self` = LinkRelation("self")
    /// Refers to the start of the actual content in a publication.
    public static let start = LinkRelation("start")

    // IANA – https://www.iana.org/assignments/link-relations/link-relations.xhtml

    /// Links to a publication manifest. A manifest represents structured information about a
    /// publication, such as informative metadata, a list of resources, and a default reading order.
    public static let publication = LinkRelation("publication")
    /// The target IRI points to a resource which represents the collection resource for the
    /// context IRI.
    public static let collection = LinkRelation("collection")
    /// Indicates that the link's context is a part of a series, and that the previous in the series
    /// is the link target.
    public static let previous = LinkRelation("previous")
    /// Indicates that the link's context is a part of a series, and that the next in the series is
    /// the link target.
    public static let next = LinkRelation("next")
    /// Refers to a resource that provides a preview of the link's context.
    public static let preview = LinkRelation("preview")

    // OPDS – https://specs.opds.io/opds-1.2.html

    /// Fallback acquisition relation when no other relation is a good fit to express the nature
    /// of the transaction.
    public static let opdsAcquisition = LinkRelation("http://opds-spec.org/acquisition")
    /// Indicates that a publication is freely accessible without any requirement, including
    /// authentication.
    public static let opdsAcquisitionOpenAccess = LinkRelation("http://opds-spec.org/acquisition/open-access")
    /// Indicates that a publication can be borrowed for a limited period of time.
    public static let opdsAcquisitionBorrow = LinkRelation("http://opds-spec.org/acquisition/borrow")
    /// Indicates that a publication can be purchased for a given price.
    public static let opdsAcquisitionBuy = LinkRelation("http://opds-spec.org/acquisition/buy")
    /// Indicates that a sub-set of the full publication is freely accessible at a given URI,
    /// without any prior requirement.
    public static let opdsAcquisitionSample = LinkRelation("http://opds-spec.org/acquisition/sample")
    /// Indicates that a publication be subscribed to, usually as part of a purchase and for a
    /// limited period of time.
    public static let opdsAcquisitionSubscribe = LinkRelation("http://opds-spec.org/acquisition/subscribe")

    /// A graphical Resource associated to the OPDS Catalog Entry.
    public static let opdsImage = LinkRelation("http://opds-spec.org/image")
    /// A reduced-size version of a graphical Resource associated to the OPS Catalog Entry.
    public static let opdsImageThumbnail = LinkRelation("http://opds-spec.org/image/thumbnail")

    /// A Resource that includes a user’s existing set of Acquired Content, which may be
    /// represented as an OPDS Catalog.
    public static let opdsShelf = LinkRelation("http://opds-spec.org/shelf")
    /// A Resource that includes a user’s set of subscriptions, which may be represented as an
    /// OPDS Catalog.
    public static let opdsSubscriptions = LinkRelation("http://opds-spec.org/subscriptions")

    /// An Acquisition Feed with a subset or an alternate order of the Publications listed.
    public static let opdsFacet = LinkRelation("http://opds-spec.org/facet")
    /// An Acquisition Feed with featured OPDS Catalog Entries. These Acquisition Feeds
    /// typically contain a subset of the OPDS Catalog Entries in an OPDS Catalog that have been
    /// selected for promotion by the OPDS Catalog provider. No order is implied.
    public static let opdsFeatured = LinkRelation("http://opds-spec.org/featured")
    /// An Acquisition Feed with recommended OPDS Catalog Entries. These Acquisition Feeds
    /// typically contain a subset of the OPDS Catalog Entries in an OPDS Catalog that have been
    /// selected specifically for the user.
    public static let opdsRecommended = LinkRelation("http://opds-spec.org/recommended")

    /// An Acquisition Feed with newly released OPDS Catalog Entries. These Acquisition Feeds
    /// typically contain a subset of the OPDS Catalog Entries in an OPDS Catalog based on the
    /// publication date of the Publication.
    public static let opdsSortNew = LinkRelation("http://opds-spec.org/sort/new")
    /// An Acquisition Feed with popular OPDS Catalog Entries. These Acquisition Feeds typically
    /// contain a subset of the OPDS Catalog Entries in an OPDS Catalog based on a numerical
    /// ranking criteria.
    public static let opdsSortPopular = LinkRelation("http://opds-spec.org/sort/popular")

    // Authentication for OPDS – https://drafts.opds.io/authentication-for-opds-1.0.html

    // Location where a client can authenticate the user with OAuth.
    public static let opdsAuthenticate = LinkRelation("authenticate")
    // Location where a client can refresh the Access Token by sending a Refresh Token.
    public static let opdsRefresh = LinkRelation("refresh")

    // Logo associated to the Catalog provider.
    public static let opdsLogo = LinkRelation("logo")
    // Location where a user can register.
    public static let opdsRegister = LinkRelation("register")
    // Support resources for the user (either a website, an email or a telephone number).
    public static let opdsHelp = LinkRelation("help")
}

extension LinkRelation: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

extension LinkRelation: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(string)
    }

    public var hashValue: Int {
        string.hashValue
    }
}

public extension Array where Element == LinkRelation {
    /// Parses multiple JSON relations into an array of `LinkRelation`.
    init(json: Any?) {
        self.init()

        if let json = json as? String {
            append(LinkRelation(json))
        } else if let json = json as? [String] {
            let rels = json.compactMap { LinkRelation($0) }
            append(contentsOf: rels)
        }
    }

    var json: [String] {
        map(\.string)
    }

    func contains(_ other: String) -> Bool {
        contains(LinkRelation(other))
    }

    func containsAny(_ others: [LinkRelation]) -> Bool {
        contains(where: { others.contains($0) })
    }

    func containsAny(_ others: LinkRelation...) -> Bool {
        containsAny(others)
    }

    func containsAny(_ others: [String]) -> Bool {
        containsAny(others.map { LinkRelation($0) })
    }

    func containsAny(_ others: String...) -> Bool {
        containsAny(others)
    }
}
