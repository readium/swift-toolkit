//
//  OPDS2Parser.swift
//  readium-opds
//
//  Created by Nikita Aizikovskyi on Jan-30-2018.
//  Copyright © 2018 Readium. All rights reserved.
//

import Foundation

import R2Shared

enum OPDS2ParserError: Error {
    case invalidJSON
    case metadataNotFound
    case invalidMetadata
    case invalidLink
    case invalidIndirectAcquisition
    case missingTitle
    case invalidFacet
    case invalidGroup
    case invalidPublication
    case invalidContributor
    case invalidCollection
    case invalidNavigation

    var localizedDescription: String {
        switch self {
        case .invalidJSON:
            return "OPDS 2 manifest is not valid JSON"
        case .metadataNotFound:
            return "Metadata not found"
        case .missingTitle:
            return "Missing title"
        case .invalidMetadata:
            return "Invalid metadata"
        case .invalidLink:
            return "Invalid link"
        case .invalidIndirectAcquisition:
            return "Invalid indirect acquisition"
        case .invalidFacet:
            return "Invalid facet"
        case .invalidGroup:
            return "Invalid group"
        case .invalidPublication:
            return "Invalid publication"
        case .invalidContributor:
            return "Invalid contributor"
        case .invalidCollection:
            return "Invalid collection"
        case .invalidNavigation:
            return "Invalid navigation"
        }
    }
}

class OPDS2Parser {
    static func parse(jsonData: Data) throws -> Feed {
        guard let jsonRoot = try? JSONSerialization.jsonObject(with: jsonData, options: []) else {
            throw OPDS2ParserError.invalidJSON
        }
        guard let topLevelDict = jsonRoot as? [String: Any] else {
            throw OPDS2ParserError.invalidJSON
        }
        guard let metadataDict = topLevelDict["metadata"] as? [String: Any] else {
            throw OPDS2ParserError.metadataNotFound

        }
        guard let title = metadataDict["title"] as? String else {
            throw OPDS2ParserError.missingTitle
        }
        let feed = Feed(title: title)
        parseMetadata(opdsMetadata: feed.metadata, metadataDict: metadataDict)

        for (k, v) in topLevelDict {
            switch k {
            case "@context":
                switch v {
                case let s as String:
                    feed.context.append(s)
                case let sArr as [String]:
                    feed.context.append(contentsOf: sArr)
                default:
                    continue
                }
            case "metadata": // Already handled above
                continue
            case "links":
                guard let links = v as? [[String: Any]] else {
                    throw OPDS2ParserError.invalidLink
                }
                try parseLinks(feed: feed, links: links)
            case "facets":
                guard let facets = v as? [[String: Any]] else {
                    throw OPDS2ParserError.invalidFacet
                }
                try parseFacets(feed: feed, facets: facets)
            case "publications":
                guard let publications = v as? [[String: Any]] else {
                    throw OPDS2ParserError.invalidPublication
                }
                try parsePublications(feed: feed, publications: publications)
            case "navigation":
                guard let navLinks = v as? [[String: Any]] else {
                    throw OPDS2ParserError.invalidNavigation
                }
                try parseNavigation(feed: feed, navLinks: navLinks)
            case "groups":
                guard let groups = v as? [[String: Any]] else {
                    throw OPDS2ParserError.invalidGroup
                }
                try parseGroups(feed: feed, groups: groups)
            default:
                continue
            }
        }

        return feed
    }

    static internal func parseMetadata(opdsMetadata: OpdsMetadata, metadataDict: [String: Any]) {
        for (k, v) in metadataDict {
            switch k {
            case "title":
                if let title = v as? String {
                    opdsMetadata.title = title
                }
            case "numberOfItems":
                opdsMetadata.numberOfItem = v as? Int
            case "itemsPerPage":
                opdsMetadata.itemsPerPage = v as? Int
            case "modified":
                if let dateStr = v as? String {
                    opdsMetadata.modified = dateStr.dateFromISO8601
                }
            case "@type":
                opdsMetadata.rdfType = v as? String
            case "currentPage":
                opdsMetadata.currentPage = v as? Int
            default:
                continue
            }
        }
    }

    static internal func parseLink(linkDict: [String: Any]) throws -> Link {
        let l = Link()
        for (k, v) in linkDict {
            switch k {
            case "title":
                l.title = v as? String
            case "href":
                l.href = v as? String
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
                l.bitrate = v as? Int
            case "duration":
                l.duration = v as? Double
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
                            guard let acquisitions = v as? [[String: Any]] else {
                                throw OPDS2ParserError.invalidLink
                            }
                            for a in acquisitions {
                                let ia = try parseIndirectAcquisition(indirectAcquisitionDict: a)
                                if prop.indirectAcquisition == nil {
                                    prop.indirectAcquisition = [ia]
                                }
                                else {
                                    prop.indirectAcquisition!.append(ia)
                                }
                            }
                        case "price":
                            guard let priceDict = v as? [String: Any],
                            let currency = priceDict["currency"] as? String,
                            let value = priceDict["value"] as? Double
                            else {
                                throw OPDS2ParserError.invalidLink
                            }
                            let price = Price(currency: currency, value: value)
                            prop.price = price
                        default:
                            continue
                        }
                    }
                }
            case "children":
                guard let childLinkDict = v as? [String: Any] else {
                    throw OPDS2ParserError.invalidLink
                }
                let childLink = try parseLink(linkDict: childLinkDict)
                l.children.append(childLink)
            default:
                continue
            }
        }
        return l
    }

    static internal func parseIndirectAcquisition(indirectAcquisitionDict: [String: Any]) throws -> IndirectAcquisition {
        guard let iaType = indirectAcquisitionDict["type"] as? String else {
            throw OPDS2ParserError.invalidIndirectAcquisition
        }
        let ia = IndirectAcquisition(typeAcquisition: iaType)
        for (k, v) in indirectAcquisitionDict {
            if (k == "child") {
                guard let childDict = v as? [String: Any] else {
                    throw OPDS2ParserError.invalidIndirectAcquisition
                }
                let child = try parseIndirectAcquisition(indirectAcquisitionDict: childDict)
                ia.child.append(child)
            }
        }
        return ia
    }

    static internal func parseFacets(feed: Feed, facets: [[String: Any]]) throws {
        for facetDict in facets {
            guard let metadata = facetDict["metadata"] as? [String: Any] else {
                throw OPDS2ParserError.invalidFacet
            }
            guard let title = metadata["title"] as? String else {
                throw OPDS2ParserError.invalidFacet
            }
            let facet = Facet(title: title)
            parseMetadata(opdsMetadata: facet.metadata, metadataDict: metadata)
            for (k, v) in facetDict {
                if (k == "links") {
                    guard let links = v as? [[String: Any]] else {
                        throw OPDS2ParserError.invalidFacet
                    }
                    for linkDict in links {
                        let link = try parseLink(linkDict: linkDict)
                        facet.links.append(link)
                    }
                }
            }
            feed.facets.append(facet)
        }
    }

    static internal func parseLinks(feed: Feed, links: [[String: Any]]) throws {
        for linkDict in links {
            let link = try parseLink(linkDict: linkDict)
            feed.links.append(link)
        }
    }

    static internal func parsePublications(feed: Feed, publications: [[String: Any]]) throws {
        for pubDict in publications {
            let pub = try parsePublication(pubDict: pubDict)
            feed.publications.append(pub)
        }
    }

    static internal func parseNavigation(feed: Feed, navLinks: [[String: Any]]) throws {
        for navDict in navLinks {
            let link = try parseLink(linkDict: navDict)
            feed.navigation.append(link)
        }
    }

    static internal func parseGroups(feed: Feed, groups: [[String: Any]]) throws {
        for groupDict in groups {
            guard let metadata = groupDict["metadata"] as? [String: Any] else {
                throw OPDS2ParserError.invalidGroup
            }
            guard let title = metadata["title"] as? String else {
                throw OPDS2ParserError.invalidGroup
            }
            let group = Group(title: title)
            parseMetadata(opdsMetadata: group.metadata, metadataDict: metadata)
            for (k, v) in groupDict {
                switch k {
                case "metadata":
                    // Already handled above
                    continue
                case "links":
                    guard let links = v as? [[String: Any]] else {
                        throw OPDS2ParserError.invalidGroup
                    }
                    for linkDict in links {
                        let link = try parseLink(linkDict: linkDict)
                        group.links.append(link)
                    }
                case "navigation":
                    guard let links = v as? [[String: Any]] else {
                        throw OPDS2ParserError.invalidGroup
                    }
                    for linkDict in links {
                        let link = try parseLink(linkDict: linkDict)
                        group.navigation.append(link)
                    }
                case "publications":
                    guard let publications = v as? [[String: Any]] else {
                        throw OPDS2ParserError.invalidGroup
                    }
                    for pubDict in publications {
                        let publication = try parsePublication(pubDict: pubDict)
                        group.publications.append(publication)
                    }
                default:
                    continue
                }
            }
            feed.groups.append(group)
        }
    }

    static internal func parsePublication(pubDict: [String: Any]) throws -> Publication {
        let p = Publication()
        for (k, v) in pubDict {
            switch k {
            case "metadata":
                guard let metadataDict = v as? [String: Any] else {
                    throw OPDS2ParserError.invalidPublication
                }
                let metadata = try parsePublicationMetadata(metadataDict: metadataDict)
                p.metadata = metadata
            case "links":
                guard let links = v as? [[String: Any]] else {
                    throw OPDS2ParserError.invalidPublication
                }
                for linkDict in links {
                    let link = try parseLink(linkDict: linkDict)
                    p.links.append(link)
                }
            case "images":
                guard let links = v as? [[String: Any]] else {
                    throw OPDS2ParserError.invalidPublication
                }
                for linkDict in links {
                    let link = try parseLink(linkDict: linkDict)
                    p.images.append(link)
                }
            default:
                continue
            }
        }
        return p
    }

    static internal func parseContributor(_ cDict: [String: Any]) throws -> Contributor {
        let c = Contributor()
        for (k, v) in cDict {
            switch k {
            case "name":
                switch v {
                case let s as String:
                    c.multilangName.singleString = s
                case let multiString as [String: String]:
                    c.multilangName.multiString = multiString
                default:
                    throw OPDS2ParserError.invalidContributor
                }
            case "identifier":
                c.identifier = v as? String
            case "sort_as":
                c.sortAs = v as? String
            case "role":
                if let s = v as? String {
                    c.roles.append(s)
                }
            case "links":
                if let linkDict = v as? [String: Any] {
                    c.links.append(try parseLink(linkDict: linkDict))
                }
            default:
                continue
            }
        }
        return c
    }

    static internal func parseContributors(_ contributors: Any) throws -> [Contributor] {
        var result: [Contributor] = []
        switch contributors {
        case let name as String:
            let c = Contributor()
            c.multilangName.singleString = name
            result.append(c)
        case let cDict as [String: Any]:
            let c = try parseContributor(cDict)
            result.append(c)
        case let cArray as [[String: Any]]:
            for cDict in cArray {
                let c = try parseContributor(cDict)
                result.append(c)
            }
        default:
            throw OPDS2ParserError.invalidContributor
        }
        return result
    }

    static internal func parseCollection(_ collectionDict: [String: Any]) throws -> R2Shared.Collection {
        guard let name = collectionDict["name"] as? String else {
            throw OPDS2ParserError.invalidCollection
        }
        let c = R2Shared.Collection(name: name)
        for (k, v) in collectionDict {
            switch k {
            case "name": // Already handled above
                continue
            case "sort_as":
                c.sortAs = v as? String
            case "identifier":
                c.identifier = v as? String
            case "position":
                c.position = v as? Double
            case "links":
                guard let links = v as? [[String: Any]] else {
                    throw OPDS2ParserError.invalidCollection
                }
                for link in links {
                    c.links.append(try parseLink(linkDict: link))
                }
            default:
                continue
            }
        }
        return c
    }

    static internal func parsePublicationMetadata(metadataDict: [String: Any]) throws -> Metadata {
        let m = Metadata()
        for (k, v) in metadataDict {
            switch k {
            case "title":
                m.multilangTitle = MultilangString()
                m.multilangTitle?.singleString = v as? String
            case "identifier":
                m.identifier = v as? String
            case "type", "@type":
                m.rdfType = v as? String
            case "modified":
                if let dateStr = v as? String {
                    m.modified = dateStr.dateFromISO8601
                }
            case "author":
                m.authors.append(contentsOf: try parseContributors(v))
            case "translator":
                m.translators.append(contentsOf: try parseContributors(v))
            case "editor":
                m.editors.append(contentsOf: try parseContributors(v))
            case "artist":
                m.artists.append(contentsOf: try parseContributors(v))
            case "illustrator":
                m.illustrators.append(contentsOf: try parseContributors(v))
            case "letterer":
                m.letterers.append(contentsOf: try parseContributors(v))
            case "penciler":
                m.pencilers.append(contentsOf: try parseContributors(v))
            case "colorist":
                m.colorists.append(contentsOf: try parseContributors(v))
            case "inker":
                m.inkers.append(contentsOf: try parseContributors(v))
            case "narrator":
                m.narrators.append(contentsOf: try parseContributors(v))
            case "contributor":
                m.contributors.append(contentsOf: try parseContributors(v))
            case "publisher":
                m.publishers.append(contentsOf: try parseContributors(v))
            case "imprint":
                m.imprints.append(contentsOf: try parseContributors(v))
            case "published":
                m.publicationDate = v as? String
            case "description":
                m.description = v as? String
            case "source":
                m.source = v as? String
            case "rights":
                m.rights = v as? String
            case "subject":
                if let subjects = v as? [[String: Any]] {
                    for subjDict in subjects {
                        let subject = Subject()
                        for (sk, sv) in subjDict {
                            switch sk {
                            case "name":
                                subject.name = sv as? String
                            case "sort_as":
                                subject.sortAs = sv as? String
                            case "scheme":
                                subject.scheme = sv as? String
                            case "code":
                                subject.code = sv as? String
                            default:
                                continue
                            }
                        }
                        m.subjects.append(subject)
                    }
                }
            case "belongs_to":
                if let belongsDict = v as? [String: Any] {
                    let belongs = BelongsTo()
                    for (bk, bv) in belongsDict {
                        switch bk {
                        case "series":
                            switch bv {
                            case let s as String:
                                belongs.series.append(R2Shared.Collection(name: s))
                            case let cArr as [[String: Any]]:
                                for cDict in cArr {
                                    belongs.series.append(try parseCollection(cDict))
                                }
                            case let cDict as [String: Any]:
                                belongs.series.append(try parseCollection(cDict))
                            default:
                                continue
                            }
                        case "collection":
                            switch bv {
                            case let s as String:
                                belongs.collection.append(R2Shared.Collection(name: s))
                            case let cArr as [[String: Any]]:
                                for cDict in cArr {
                                    belongs.collection.append(try parseCollection(cDict))
                                }
                            case let cDict as [String: Any]:
                                belongs.collection.append(try parseCollection(cDict))
                            default:
                                continue
                            }
                        default:
                            continue
                        }
                    }
                    m.belongsTo = belongs
                }
            case "duration":
                m.duration = v as? Int
            case "language":
                switch v {
                case let s as String:
                    m.languages.append(s)
                case let sArr as [String]:
                    m.languages.append(contentsOf: sArr)
                default:
                    continue
                }
            default:
                continue
            }
        }
        return m
    }

}
