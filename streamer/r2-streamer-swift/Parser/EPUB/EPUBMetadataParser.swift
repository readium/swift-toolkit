//
//  EPUBMetadataParser.swift
//  r2-streamer-swift
//
//  Created by Alexandre Camilleri, Mickaël Menu on 3/17/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import R2Shared
import Fuzi


/// Reference: https://github.com/readium/architecture/blob/master/streamer/parser/metadata.md
final class EPUBMetadataParser: Loggable {
    
    private let document: Fuzi.XMLDocument
    private let displayOptions: Fuzi.XMLDocument?
    private let metas: OPFMetaList

    init(document: Fuzi.XMLDocument, displayOptions: Fuzi.XMLDocument?, metas: OPFMetaList) {
        self.document = document
        self.displayOptions = displayOptions
        self.metas = metas
        
        document.definePrefix("opf", forNamespace: "http://www.idpf.org/2007/opf")
        document.definePrefix("dc", forNamespace: "http://purl.org/dc/elements/1.1/")
        document.definePrefix("dcterms", forNamespace: "http://purl.org/dc/terms/")
        document.definePrefix("rendition", forNamespace: "http://www.idpf.org/2013/rendition")
    }
    
    private lazy var metadataElement: Fuzi.XMLElement? = {
        return document.firstChild(xpath: "/opf:package/opf:metadata")
    }()

    /// Parses the Metadata in the XML <metadata> element.
    func parse() throws -> Metadata {
        guard let title = mainTitle else {
            throw OPFParserError.missingPublicationTitle
        }
        
        var otherMetadata = metas.otherMetadata
        if !presentation.json.isEmpty {
            otherMetadata["presentation"] = presentation.json
        }
        
        let contributors = parseContributors()
        
        return Metadata(
            identifier: uniqueIdentifier,
            title: title,
            subtitle: subtitle,
            modified: modifiedDate,
            published: publishedDate,
            languages: languages,
            sortAs: sortAs,
            subjects: subjects,
            authors: contributors.authors,
            translators: contributors.translators,
            editors: contributors.editors,
            artists: contributors.artists,
            illustrators: contributors.illustrators,
            colorists: contributors.colorists,
            narrators: contributors.narrators,
            contributors: contributors.contributors,
            publishers: contributors.publishers,
            readingProgression: readingProgression,
            description: description,
            numberOfPages: numberOfPages,
            belongsToCollections: belongsToCollections,
            belongsToSeries: belongsToSeries,
            otherMetadata: otherMetadata
        )
    }
    
    private lazy var languages: [String] = metas["language", in: .dcterms].map { $0.content }

    private lazy var packageLanguage: String? = document.firstChild(xpath: "/opf:package")?.attr("lang")

    /// Determines the BCP-47 language tag for the given element, using:
    ///   1. its xml:lang attribute
    ///   2. the package's xml:lang attribute
    ///   3. the primary language for the publication
    private func language(for element: Fuzi.XMLElement) -> String? {
        return element.attr("lang") ?? packageLanguage ?? languages.first
    }
    
    /// https://github.com/readium/architecture/blob/master/streamer/parser/metadata.md#title
    private lazy var sortAs: String? = {
        // EPUB 3
        if let id = mainTitleElement?.attr("id"), let sortAsElement = metas["file-as", refining: id].first {
            return sortAsElement.content
        // EPUB 2
        } else {
            return metas["title_sort", in: .calibre].first?.content
        }
    }()
    
    private lazy var description: String? = metas["description", in: .dcterms]
        .first?.content

    private lazy var numberOfPages: Int? = metas["numberOfPages", in: .schema]
        .first.flatMap { Int($0.content) }
    
    /// Extracts the Presentation properties from the XML element metadata and fill
    /// them into the Metadata object instance.
    private lazy var presentation: Presentation = {
        func renditionMetadata(_ property: String) -> String {
            return metas[property, in: .rendition].last?.content ?? ""
        }

        func displayOption(_ name: String) -> String? {
            // https://readium.org/architecture/streamer/parser/metadata#epub-2x-10
            guard let platform = displayOptions?.firstChild(xpath: "platform[@name='*']")
                ?? displayOptions?.firstChild(xpath: "platform[@name='ipad']")
                ?? displayOptions?.firstChild(xpath: "platform[@name='iphone']")
                ?? displayOptions?.firstChild(xpath: "platform") else
            {
                return nil
            }
            return platform.firstChild(xpath: "option[@name='\(name)']")?.stringValue
        }

        return Presentation(
            continuous: (renditionMetadata("flow") == "scrolled-continuous"),
            orientation: .init(
                epub: renditionMetadata("orientation"),
                fallback: {
                    let orientationLock = displayOption("orientation-lock") ?? ""
                    switch orientationLock {
                    case "none":
                        return .auto
                    case "landscape-only":
                        return .landscape
                    case "portrait-only":
                        return .portrait
                    default:
                        return nil
                    }
                }()
            ),
            overflow: .init(epub: renditionMetadata("flow")),
            spread: .init(epub: renditionMetadata("spread")),
            layout: .init(
                epub: renditionMetadata("layout"),
                fallback: (displayOption("fixed-layout") == "true") ? .fixed : nil
            )
        )
    }()

    /// Finds all the `<dc:title> element matching the given `title-type`.
    /// The elements are then sorted by the `display-seq` refines, when available.
    private func titleElements(ofType titleType: EPUBTitleType) -> [Fuzi.XMLElement] {
        // Finds the XML element corresponding to the specific title type
        // `<meta refines="#.." property="title-type" id="title-type">titleType</meta>`
        return metas["title-type"]
            .compactMap { meta in
                guard meta.content == titleType.rawValue, let id = meta.refines else {
                    return nil
                }
                return metas["title", in: .dcterms].first { $0.id == id }?.element
            }
            // Sort using `display-seq` refines
            .sorted { title1, title2 in
                let order1 = title1.attr("id").flatMap { displaySeqs[$0] } ?? ""
                let order2 = title2.attr("id").flatMap { displaySeqs[$0] } ?? ""
                return order1 < order2
            }
    }
    
    /// Maps between an element ID and its `display-seq` refine, if there's any.
    /// eg. <meta refines="#creator01" property="display-seq">1</meta>
    private lazy var displaySeqs: [String: String] = {
        return metas["display-seq"]
            .reduce([:]) { displaySeqs, meta in
                var displaySeqs = displaySeqs
                if let id = meta.refines {
                    displaySeqs[id] = meta.content
                }
                return displaySeqs
            }
    }()
    
    private lazy var mainTitleElement: Fuzi.XMLElement? = titleElements(ofType: .main).first
        ?? metas["title", in: .dcterms].first?.element
    
    private lazy var mainTitle: LocalizedString? = localizedString(for: mainTitleElement)

    private lazy var subtitle: LocalizedString? = localizedString(for: titleElements(ofType: .subtitle).first)

    /// Parse and return the Epub unique identifier.
    /// https://github.com/readium/architecture/blob/master/streamer/parser/metadata.md#identifier
    private lazy var uniqueIdentifier: String? =
        dcElement(tag: "identifier[@id=/opf:package/@unique-identifier]")?
            .stringValue

    /// https://github.com/readium/architecture/blob/master/streamer/parser/metadata.md#publication-date
    private lazy var publishedDate =
        dcElement(tag: "date[not(@opf:event) or @opf:event='publication']")?
            .stringValue.dateFromISO8601

    /// Parse the modifiedDate (date of last modification of the EPUB).
    /// https://github.com/readium/architecture/blob/master/streamer/parser/metadata.md#modification-date
    private lazy var modifiedDate: Date? = {
        let epub3Date = {
            self.metas["modified", in: .dcterms]
                .compactMap { $0.content.dateFromISO8601 }
                .first
        }
        let epub2Date = {
            self.dcElement(tag: "date[@opf:event='modification']")?
                .stringValue.dateFromISO8601
        }
        return epub3Date() ?? epub2Date()
    }()

    /// Parses the <dc:subject> XML element from the metadata
    /// https://github.com/readium/architecture/blob/master/streamer/parser/metadata.md#subjects
    private lazy var subjects: [Subject] = {
        guard let metadataElement = metadataElement else {
            return []
        }
        
        let subjects = metas["subject", in: .dcterms]
        if subjects.count == 1 {
            let subject = subjects[0]
            let names = subject.content.components(separatedBy: CharacterSet(charactersIn: ",;"))
            if names.count > 1 {
                // No translations if the subjects are a list separated by , or ;
                return names.compactMap {
                    let name = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else {
                        return nil
                    }
                    return Subject(
                        name: name,
                        scheme: subject.element.attr("authority"),
                        code: subject.element.attr("term")
                    )
                }
            }
        }
            
        return subjects.compactMap {
            guard let name = localizedString(for: $0.element) else {
                return nil
            }
            return Subject(
                name: name,
                scheme: $0.element.attr("authority"),
                code: $0.element.attr("term")
            )
        }
    }()

    /// Parse all the Contributors objects of the model (`creator`, `contributor`,
    /// `publisher`) and add them to the metadata.
    ///
    /// - Parameters:
    ///   - metadata: The Metadata object to fill (inout).
    private func parseContributors() -> (
        authors: [Contributor],
        translators: [Contributor],
        editors: [Contributor],
        artists: [Contributor],
        illustrators: [Contributor],
        colorists: [Contributor],
        narrators: [Contributor],
        contributors: [Contributor],
        publishers: [Contributor]
    ) {
        var authors: [Contributor] = []
        var translators: [Contributor] = []
        var editors: [Contributor] = []
        var artists: [Contributor] = []
        var illustrators: [Contributor] = []
        var colorists: [Contributor] = []
        var narrators: [Contributor] = []
        var contributors: [Contributor] = []
        var publishers: [Contributor] = []
        
        for element in findContributorElements() {
            // Look up for possible meta refines for contributor's role.
            let roles = element.attr("id")
                .map { id in metas["role", refining: id].map { $0.content } }
                ?? []
            
            guard let contributor = createContributor(from: element, roles: roles) else {
                continue
            }
            // Add the contributor to the proper property according to its `roles`
            if !contributor.roles.isEmpty {
                for role in contributor.roles {
                    switch role {
                    case "aut":
                        authors.append(contributor)
                    case "trl":
                        translators.append(contributor)
                    case "art":
                        artists.append(contributor)
                    case "edt":
                        editors.append(contributor)
                    case "ill":
                        illustrators.append(contributor)
                    case "clr":
                        colorists.append(contributor)
                    case "nrt":
                        narrators.append(contributor)
                    case "pbl":
                        publishers.append(contributor)
                    default:
                        contributors.append(contributor)
                    }
                }
            } else {
                // No role, so do the branching using the element.name.
                // The remaining ones go to to the contributors.
                if element.tag == "creator" || element.attr("property") == "dcterms:creator" {
                    authors.append(contributor)
                } else if element.tag == "publisher" || element.attr("property") == "dcterms:publisher" {
                    publishers.append(contributor)
                } else {
                    contributors.append(contributor)
                }
            }
        }
        
        return (
            authors: authors,
            translators: translators,
            editors: editors,
            artists: artists,
            illustrators: illustrators,
            colorists: colorists,
            narrators: narrators,
            contributors: contributors,
            publishers: publishers
        )
    }

    /// Returns the XML elements about the contributors.
    /// e.g. `<dc:publisher "property"=".." >value<\>`,
    /// or `<meta property="dcterms:publisher/creator/contributor"`
    ///
    /// - Parameter metadata: The XML metadata element.
    /// - Returns: The array of XML element representing the contributors.
    private func findContributorElements() -> [Fuzi.XMLElement] {
        let contributors = metas["creator", in: .dcterms]
            + metas["publisher", in: .dcterms]
            + metas["contributor", in: .dcterms]
        return contributors.map { $0.element }
    }

    /// Builds a `Contributor` instance from a `<dc:creator>`, `<dc:contributor>`
    /// or <dc:publisher> element, or <meta> element with property == "dcterms:
    /// creator", "dcterms:publisher", "dcterms:contributor".
    ///
    /// - Parameters:
    ///   - element: The XML element reprensenting the contributor.
    /// - Returns: The newly created Contributor instance.
    private func createContributor(from element: Fuzi.XMLElement, roles: [String] = []) -> Contributor? {
        guard let name = localizedString(for: element) else {
            return nil
        }
        
        var roles = roles
        if let role = element.attr("role") {
            roles.insert(role, at: 0)
        }
        
        return Contributor(
            name: name,
            sortAs: element.attr("file-as"),
            roles: roles
        )
    }

    private lazy var readingProgression: ReadingProgression = {
        let direction = document.firstChild(xpath: "/opf:package/opf:readingOrder|/opf:package/opf:spine")?.attr("page-progression-direction") ?? "default"
        switch direction {
        case "ltr":
            return .ltr
        case "rtl":
            return .rtl
        default:
            return .auto
        }
    }()
    
    /// https://github.com/readium/architecture/blob/master/streamer/parser/metadata.md#collections-and-series
    private lazy var belongsToCollections: [Metadata.Collection] = {
        return metas["belongs-to-collection"]
            // `collection-type` should not be "series"
            .filter { meta in
                if let id = meta.id {
                    return metas["collection-type", refining: id].first?.content != "series"
                }
                return true
            }
            .compactMap(collection(from:))
    }()

    /// https://github.com/readium/architecture/blob/master/streamer/parser/metadata.md#collections-and-series
    private lazy var belongsToSeries: [Metadata.Collection] = {
        let epub3Series = metas["belongs-to-collection"]
            // `collection-type` should be "series"
            .filter { meta in
                guard let id = meta.id else {
                    return false
                }
                return metas["collection-type", refining: id].first?.content == "series"
            }
            .compactMap(collection(from:))
        
        let epub2Position = metas["series_index", in: .calibre].first
            .flatMap { Double($0.content) }
        let epub2Series = metas["series", in: .calibre]
            .map { meta in
                Metadata.Collection(
                    name: meta.content,
                    position: epub2Position
                )
            }

        return epub3Series + epub2Series
    }()
    
    private func collection(from meta: OPFMeta) -> Metadata.Collection? {
        guard let name = localizedString(for: meta.element) else {
            return nil
        }
        return Metadata.Collection(
            name: name,
            identifier: meta.id.flatMap { metas["identifier", in: .dcterms, refining: $0].first?.content },
            sortAs: meta.id.flatMap { metas["file-as", refining: $0].first?.content },
            position: meta.id
                .flatMap { metas["group-position", refining: $0].first?.content }
                .flatMap { Double($0) }
        )
    }

    /// Return a localized string, defining the multiple representations of a string in different languages.
    ///
    /// - Parameters:
    ///   - element: The element to parse (can be a title or a contributor).
    private func localizedString(for element: Fuzi.XMLElement?) -> LocalizedString? {
        guard let element = element else {
            return nil
        }
        
        var strings: [String: String] = [:]
        
        // Default string
        let defaultString = element.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let defaultLanguage = language(for: element) else {
            return defaultString.localizedString
        }
        strings[defaultLanguage] = defaultString

        // Finds translations
        if let elementID = element.attr("id") {
            // Find the <meta refines="elementId" property="alternate-script"> in order to find the alternative strings, if any.
            for altScriptMeta in metas["alternate-script", refining: elementID] {
                // If it have a value then add it to the translations dictionnary.
                let value = altScriptMeta.content.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !value.isEmpty, let lang = altScriptMeta.element.attr("lang") else {
                    continue
                }
                strings[lang] = value
            }
        }
        
        if strings.count > 1 {
            return strings.localizedString
        } else {
            return strings.first?.value.localizedString
        }
    }
    
    /// Returns the given `dc:` tag in the `metadata` element.
    ///
    /// This looks under `metadata/dc-metadata` as well, to be compatible with old EPUB 2 files.
    private func dcElement(tag: String) -> XMLElement? {
        return metadataElement?
            .firstChild(xpath:"(.|opf:dc-metadata)/dc:\(tag)")
    }
    
}
