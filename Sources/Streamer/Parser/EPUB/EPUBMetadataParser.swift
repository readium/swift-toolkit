//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumFuzi
import ReadiumShared

/// Reference: https://github.com/readium/architecture/blob/master/streamer/parser/metadata.md
final class EPUBMetadataParser: Loggable {
    private let document: ReadiumFuzi.XMLDocument
    private let displayOptions: ReadiumFuzi.XMLDocument?
    private let metas: OPFMetaList

    init(document: ReadiumFuzi.XMLDocument, displayOptions: ReadiumFuzi.XMLDocument?, metas: OPFMetaList) {
        self.document = document
        self.displayOptions = displayOptions
        self.metas = metas

        document.defineNamespace(.opf)
        document.defineNamespace(.dc)
        document.defineNamespace(.dcterms)
        document.defineNamespace(.rendition)
    }

    private lazy var metadataElement: ReadiumFuzi.XMLElement? = document.firstChild(xpath: "/opf:package/opf:metadata")

    /// Parses the Metadata in the XML <metadata> element.
    func parse() throws -> Metadata {
        let contributorsWithRoles = findContributorElements()
            .compactMap { createContributor(from: $0) }

        let contributorsByRole = Dictionary(grouping: contributorsWithRoles, by: \.role)
            .mapValues { $0.map(\.contributor) }

        func contributorsForRole(role: String?) -> [Contributor] {
            contributorsByRole[role] ?? []
        }

        return Metadata(
            identifier: uniqueIdentifier,
            conformsTo: [.epub],
            title: mainTitle,
            subtitle: subtitle,
            accessibility: accessibility(),
            modified: modifiedDate,
            published: publishedDate,
            languages: languages,
            sortAs: sortAs,
            subjects: subjects,
            authors: contributorsForRole(role: "aut"),
            translators: contributorsForRole(role: "trl"),
            editors: contributorsForRole(role: "edt"),
            artists: contributorsForRole(role: "art"),
            illustrators: contributorsForRole(role: "ill"),
            colorists: contributorsForRole(role: "clr"),
            narrators: contributorsForRole(role: "nrt"),
            contributors: contributorsForRole(role: nil),
            publishers: contributorsForRole(role: "pbl"),
            layout: layout(),
            readingProgression: readingProgression,
            description: description,
            numberOfPages: numberOfPages,
            belongsToCollections: belongsToCollections,
            belongsToSeries: belongsToSeries,
            tdm: tdm(),
            otherMetadata: metas.otherMetadata
        )
    }

    private lazy var languages: [String] = metas["language", in: .dcterms].map(\.content)

    private lazy var packageLanguage: String? = document.firstChild(xpath: "/opf:package")?.attr("lang")

    /// Determines the BCP-47 language tag for the given element, using:
    ///   1. its xml:lang attribute
    ///   2. the package's xml:lang attribute
    ///   3. the primary language for the publication
    private func language(for element: ReadiumFuzi.XMLElement) -> String? {
        element.attr("lang") ?? packageLanguage ?? languages.first
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

    private func layout() -> Layout {
        func displayOption(_ name: String) -> String? {
            // https://readium.org/architecture/streamer/parser/metadata#epub-2x-10
            guard let platform = displayOptions?.firstChild(xpath: "platform[@name='*']")
                ?? displayOptions?.firstChild(xpath: "platform[@name='ipad']")
                ?? displayOptions?.firstChild(xpath: "platform[@name='iphone']")
                ?? displayOptions?.firstChild(xpath: "platform")
            else {
                return nil
            }
            return platform.firstChild(xpath: "option[@name='\(name)']")?.stringValue
        }

        let layoutMetadata = metas["layout", in: .rendition].last?.content ?? ""

        return Layout(epub: layoutMetadata)
            ?? ((displayOption("fixed-layout") == "true") ? .fixed : .reflowable)
    }

    /// Finds all the `<dc:title> element matching the given `title-type`.
    /// The elements are then sorted by the `display-seq` refines, when available.
    private func titleElements(ofType titleType: EPUBTitleType) -> [ReadiumFuzi.XMLElement] {
        // Finds the XML element corresponding to the specific title type
        // `<meta refines="#.." property="title-type" id="title-type">titleType</meta>`
        metas["title-type"]
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
        metas["display-seq"]
            .reduce([:]) { displaySeqs, meta in
                var displaySeqs = displaySeqs
                if let id = meta.refines {
                    displaySeqs[id] = meta.content
                }
                return displaySeqs
            }
    }()

    private lazy var mainTitleElement: ReadiumFuzi.XMLElement? = titleElements(ofType: .main).first
        ?? metas["title", in: .dcterms].first?.element

    private lazy var mainTitle: LocalizedString? = localizedString(for: mainTitleElement)

    private lazy var subtitle: LocalizedString? = localizedString(for: titleElements(ofType: .subtitle).first)

    /// https://readium.org/architecture/streamer/parser/a11y-metadata-parsing
    private func accessibility() -> Accessibility? {
        let accessibility: Accessibility? = Accessibility(
            conformsTo: accessibilityProfiles(),
            certification: accessibilityCertification(),
            summary: metas["accessibilitySummary", in: .schema].first?.content,
            accessModes: accessibilityAccessModes(),
            accessModesSufficient: accessibilityAccessModesSufficient(),
            features: accessibilityFeatures(),
            hazards: accessibilityHazards(),
            exemptions: accessibilityExemptions()
        )

        return accessibility.takeIf { $0 != Accessibility() }
    }

    private func accessibilityProfiles() -> [Accessibility.Profile] {
        let hrefs = metas["conformsTo", in: .dcterms].map(\.content)
            + metas.links(withRel: "conformsTo", in: .dcterms).map(\.href)
        return hrefs.compactMap { accessibilityProfile(from: $0) }
    }

    private func accessibilityProfile(from value: String) -> Accessibility.Profile? {
        switch value {
        case "http://idpf.org/epub/a11y/accessibility-20170105.html#wcag-a",
             "http://www.idpf.org/epub/a11y/accessibility-20170105.html#wcag-a",
             "https://idpf.org/epub/a11y/accessibility-20170105.html#wcag-a",
             "https://www.idpf.org/epub/a11y/accessibility-20170105.html#wcag-a":
            return .epubA11y10WCAG20A

        case "http://idpf.org/epub/a11y/accessibility-20170105.html#wcag-aa",
             "http://www.idpf.org/epub/a11y/accessibility-20170105.html#wcag-aa",
             "https://idpf.org/epub/a11y/accessibility-20170105.html#wcag-aa",
             "https://www.idpf.org/epub/a11y/accessibility-20170105.html#wcag-aa":
            return .epubA11y10WCAG20AA

        case "http://idpf.org/epub/a11y/accessibility-20170105.html#wcag-aaa",
             "http://www.idpf.org/epub/a11y/accessibility-20170105.html#wcag-aaa",
             "https://idpf.org/epub/a11y/accessibility-20170105.html#wcag-aaa",
             "https://www.idpf.org/epub/a11y/accessibility-20170105.html#wcag-aaa":
            return .epubA11y10WCAG20AAA

        case "EPUB Accessibility 1.1 - WCAG 2.0 Level A":
            return .epubA11y11WCAG20A

        case "EPUB Accessibility 1.1 - WCAG 2.0 Level AA":
            return .epubA11y11WCAG20AA

        case "EPUB Accessibility 1.1 - WCAG 2.0 Level AAA":
            return .epubA11y11WCAG20AAA

        case "EPUB Accessibility 1.1 - WCAG 2.1 Level A":
            return .epubA11y11WCAG21A

        case "EPUB Accessibility 1.1 - WCAG 2.1 Level AA":
            return .epubA11y11WCAG21AA

        case "EPUB Accessibility 1.1 - WCAG 2.1 Level AAA":
            return .epubA11y11WCAG21AAA

        case "EPUB Accessibility 1.1 - WCAG 2.2 Level A":
            return .epubA11y11WCAG22A

        case "EPUB Accessibility 1.1 - WCAG 2.2 Level AA":
            return .epubA11y11WCAG22AA

        case "EPUB Accessibility 1.1 - WCAG 2.2 Level AAA":
            return .epubA11y11WCAG22AAA

        default:
            return nil
        }
    }

    private func accessibilityCertification() -> Accessibility.Certification? {
        let certifier = metas["certifiedBy", in: .a11y].first
        let credential: String?
        let report: String?
        if let id = certifier?.id {
            credential = metas["certifierCredential", in: .a11y, refining: id].first?.content
            report = metas.links(withRel: "certifierReport", in: .a11y, refining: id).first?.href
        } else {
            credential = metas["certifierCredential", in: .a11y].first?.content
            report = metas["certifierReport", in: .a11y].first?.content
                ?? metas.links(withRel: "certifierReport", in: .a11y).first?.href
        }
        guard certifier != nil || credential != nil || report != nil else {
            return nil
        }

        return Accessibility.Certification(
            certifiedBy: certifier?.content,
            credential: credential,
            report: report
        )
    }

    private func accessibilityAccessModes() -> [Accessibility.AccessMode] {
        metas["accessMode", in: .schema]
            .map { Accessibility.AccessMode($0.content) }
    }

    private func accessibilityAccessModesSufficient() -> [[Accessibility.PrimaryAccessMode]] {
        metas["accessModeSufficient", in: .schema]
            .map {
                $0.content.split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .compactMap(Accessibility.PrimaryAccessMode.init(rawValue:))
            }
    }

    private func accessibilityFeatures() -> [Accessibility.Feature] {
        metas["accessibilityFeature", in: .schema]
            .map { Accessibility.Feature($0.content) }
    }

    private func accessibilityHazards() -> [Accessibility.Hazard] {
        metas["accessibilityHazard", in: .schema]
            .map { Accessibility.Hazard($0.content) }
    }

    private func accessibilityExemptions() -> [Accessibility.Exemption] {
        metas["exemption", in: .a11y]
            .map { Accessibility.Exemption($0.content) }
    }

    /// https://www.w3.org/community/reports/tdmrep/CG-FINAL-tdmrep-20240510/#sec-epub3
    private func tdm() -> TDM? {
        guard
            let reservationMeta = metas["reservation", in: .tdm].first,
            let reservation = TDM.Reservation(epub: reservationMeta)
        else {
            return nil
        }

        return TDM(
            reservation: reservation,
            policy: metas["policy", in: .tdm].first
                .flatMap { HTTPURL(string: $0.content) }
        )
    }

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
                .compactMap(\.content.dateFromISO8601)
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

    /// Returns the XML elements about the contributors.
    /// e.g. `<dc:publisher "property"=".." >value<\>`,
    /// or `<meta property="dcterms:publisher/creator/contributor"`
    ///
    /// - Parameter metadata: The XML metadata element.
    /// - Returns: The array of XML element representing the contributors.
    private func findContributorElements() -> [ReadiumFuzi.XMLElement] {
        let contributors = metas["creator", in: .dcterms]
            + metas["publisher", in: .dcterms]
            + metas["contributor", in: .dcterms]
            + metas["narrator", in: .media]
        return contributors.map(\.element)
    }

    /// Builds a `Contributor` instance from a `<dc:creator>`, `<dc:contributor>`
    /// or <dc:publisher> element, or <meta> element with property == "dcterms:
    /// creator", "dcterms:publisher", "dcterms:contributor".
    ///
    /// - Parameters:
    ///   - element: The XML element reprensenting the contributor.
    /// - Returns: The newly created Contributor instance.
    private func createContributor(from element: ReadiumFuzi.XMLElement) -> (role: String?, contributor: Contributor)? {
        guard let name = localizedString(for: element) else {
            return nil
        }

        let knownRoles: Set = ["aut", "trl", "edt", "pbl", "art", "ill", "clr", "nrt"]

        // Look up for possible meta refines for contributor's role.
        let role: String? = element.attr("id")
            .map { id in metas["role", refining: id].map(\.content) }?.first
            ?? element.attr("role") // falls back to EPUB 2 role attribute

        let roles = role.map { role in knownRoles.contains(role) ? [] : [role] } ?? []

        let contributor = Contributor(
            name: name,
            sortAs: element.attr("file-as"),
            roles: roles
        )

        let type: String? = if element.tag == "creator" || element.attr("property") == "dcterms:creator" {
            "aut"
        } else if element.tag == "publisher" || element.attr("property") == "dcterms:publisher" {
            "pbl"
        } else if element.tag == "narrator" {
            "nrt"
        } else if role == nil {
            nil
        } else {
            knownRoles.contains(role!) ? role : nil
        }

        return (role: type, contributor: contributor)
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
        metas["belongs-to-collection"]
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
        let calibrePosition = metas["series_index", in: .calibre].first
            .flatMap { Double($0.content) }

        let calibreSeries = metas["series", in: .calibre]
            .map { meta in
                Metadata.Collection(
                    name: meta.content,
                    position: calibrePosition
                )
            }

        if !calibreSeries.isEmpty {
            return calibreSeries
        }

        let epub3Series = metas["belongs-to-collection"]
            // `collection-type` should be "series"
            .filter { meta in
                guard let id = meta.id else {
                    return false
                }
                return metas["collection-type", refining: id].first?.content == "series"
            }
            .compactMap(collection(from:))

        return epub3Series
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
    private func localizedString(for element: ReadiumFuzi.XMLElement?) -> LocalizedString? {
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
    private func dcElement(tag: String) -> ReadiumFuzi.XMLElement? {
        metadataElement?
            .firstChild(xpath: "(.|opf:dc-metadata)/dc:\(tag)")
    }
}

private extension TDM.Reservation {
    init?(epub: OPFMeta) {
        switch epub.content {
        case "0":
            self = .none
        case "1":
            self = .all
        default:
            return nil
        }
    }
}
