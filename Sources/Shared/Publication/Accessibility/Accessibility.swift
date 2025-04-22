//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// Holds the accessibility metadata of a Publication.
///
/// https://www.w3.org/2021/a11y-discov-vocab/latest/
/// https://readium.org/webpub-manifest/schema/a11y.schema.json
public struct Accessibility: Hashable, Sendable {
    /// An established standard to which the described resource conforms.
    public var conformsTo: [Profile]

    /// Certification of accessible publications.
    public var certification: Certification?

    /// A human-readable summary of specific accessibility features or deficiencies, consistent with the other
    /// accessibility metadata but expressing subtleties such as "short descriptions are present but long descriptions
    /// will be needed for non-visual users" or "short descriptions are present and no long descriptions are needed."
    ///
    /// https://www.w3.org/2021/a11y-discov-vocab/latest/#accessibilitySummary
    public var summary: String?

    /// The human sensory perceptual system or cognitive faculty through which a person may process or perceive
    /// information.
    ///
    /// https://www.w3.org/2021/a11y-discov-vocab/latest/#accessMode
    public var accessModes: [AccessMode]

    /// A list of single or combined accessModes that are sufficient to understand all the intellectual content of a
    /// resource.
    ///
    /// https://www.w3.org/2021/a11y-discov-vocab/latest/#accessModeSufficient
    public var accessModesSufficient: [[PrimaryAccessMode]]

    /// Content features of the resource, such as accessible media, alternatives and supported enhancements for
    /// accessibility.
    ///
    /// https://www.w3.org/2021/a11y-discov-vocab/latest/#accessibilityFeature
    public var features: [Feature]

    /// A characteristic of the described resource that is physiologically dangerous to some users.
    ///
    /// https://www.w3.org/2021/a11y-discov-vocab/latest/#accessibilityHazard
    public var hazards: [Hazard]

    /// Justifications for non-conformance based on exemptions in a given
    /// jurisdiction.
    public var exemptions: [Exemption]

    /// Accessibility profile.
    public struct Profile: Hashable, Sendable {
        public let uri: String

        public init(_ uri: String) {
            self.uri = uri
        }

        /// EPUB Accessibility 1.0 - WCAG 2.0 Level A
        public static let epubA11y10WCAG20A = Profile("http://www.idpf.org/epub/a11y/accessibility-20170105.html#wcag-a")
        /// EPUB Accessibility 1.0 - WCAG 2.0 Level AA
        public static let epubA11y10WCAG20AA = Profile("http://www.idpf.org/epub/a11y/accessibility-20170105.html#wcag-aa")
        /// EPUB Accessibility 1.0 - WCAG 2.0 Level AAA
        public static let epubA11y10WCAG20AAA = Profile("http://www.idpf.org/epub/a11y/accessibility-20170105.html#wcag-aaa")
        /// EPUB Accessibility 1.1 - WCAG 2.0 Level A
        public static let epubA11y11WCAG20A = Profile("https://www.w3.org/TR/epub-a11y-11#wcag-2.0-a")
        /// EPUB Accessibility 1.1 - WCAG 2.0 Level AA
        public static let epubA11y11WCAG20AA = Profile("https://www.w3.org/TR/epub-a11y-11#wcag-2.0-aa")
        /// EPUB Accessibility 1.1 - WCAG 2.0 Level AAA
        public static let epubA11y11WCAG20AAA = Profile("https://www.w3.org/TR/epub-a11y-11#wcag-2.0-aaa")
        /// EPUB Accessibility 1.1 - WCAG 2.1 Level A
        public static let epubA11y11WCAG21A = Profile("https://www.w3.org/TR/epub-a11y-11#wcag-2.1-a")
        /// EPUB Accessibility 1.1 - WCAG 2.1 Level AA
        public static let epubA11y11WCAG21AA = Profile("https://www.w3.org/TR/epub-a11y-11#wcag-2.1-aa")
        /// EPUB Accessibility 1.1 - WCAG 2.1 Level AAA
        public static let epubA11y11WCAG21AAA = Profile("https://www.w3.org/TR/epub-a11y-11#wcag-2.1-aaa")
        /// EPUB Accessibility 1.1 - WCAG 2.2 Level A
        public static let epubA11y11WCAG22A = Profile("https://www.w3.org/TR/epub-a11y-11#wcag-2.2-a")
        /// EPUB Accessibility 1.1 - WCAG 2.2 Level AA
        public static let epubA11y11WCAG22AA = Profile("https://www.w3.org/TR/epub-a11y-11#wcag-2.2-aa")
        /// EPUB Accessibility 1.1 - WCAG 2.2 Level AAA
        public static let epubA11y11WCAG22AAA = Profile("https://www.w3.org/TR/epub-a11y-11#wcag-2.2-aaa")

        /// Indicates whether this profile matches WCAG level A.
        public var isWCAGLevelA: Bool {
            self == Self.epubA11y10WCAG20A
                || self == Self.epubA11y11WCAG20A
                || self == Self.epubA11y11WCAG21A
                || self == Self.epubA11y11WCAG22A
        }

        /// Indicates whether this profile matches WCAG level AA.
        public var isWCAGLevelAA: Bool {
            self == Self.epubA11y10WCAG20AA
                || self == Self.epubA11y11WCAG20AA
                || self == Self.epubA11y11WCAG21AA
                || self == Self.epubA11y11WCAG22AA
        }

        /// Indicates whether this profile matches WCAG level AAA.
        public var isWCAGLevelAAA: Bool {
            self == Self.epubA11y10WCAG20AAA
                || self == Self.epubA11y11WCAG20AAA
                || self == Self.epubA11y11WCAG21AAA
                || self == Self.epubA11y11WCAG22AAA
        }
    }

    public struct Certification: Hashable, Sendable {
        /// Identifies a party responsible for the testing and certification of the accessibility of a Publication.
        ///
        /// https://www.w3.org/TR/epub-a11y/#certifiedBy
        public var certifiedBy: String?

        /// Identifies a credential or badge that establishes the authority of the party identified in the associated
        /// `certifiedBy` property to certify content accessible.
        ///
        /// https://www.w3.org/TR/epub-a11y/#certifierCredential
        public var credential: String?

        /// Provides a link to an accessibility report created by the party identified in the associated certifiedBy
        /// property.
        ///
        /// https://www.w3.org/TR/epub-a11y/#certifierReport
        public var report: String?

        public init(certifiedBy: String? = nil, credential: String? = nil, report: String? = nil) {
            self.certifiedBy = certifiedBy
            self.credential = credential
            self.report = report
        }
    }

    public struct AccessMode: Hashable, Sendable {
        public let id: String

        public init(_ id: String) {
            self.id = id
        }

        /// Indicates that the resource contains information encoded in auditory form.
        public static let auditory = AccessMode("auditory")

        /// Indicates that the resource contains charts encoded in visual form.
        public static let chartOnVisual = AccessMode("chartOnVisual")

        /// Indicates that the resource contains chemical equations encoded in visual form.
        public static let chemOnVisual = AccessMode("chemOnVisual")

        /// Indicates that the resource contains information encoded such that color perception is necessary.
        public static let colorDependent = AccessMode("colorDependent")

        /// Indicates that the resource contains diagrams encoded in visual form.
        public static let diagramOnVisual = AccessMode("diagramOnVisual")

        /// Indicates that the resource contains mathematical notations encoded in visual form.
        public static let mathOnVisual = AccessMode("mathOnVisual")

        /// Indicates that the resource contains musical notation encoded in visual form.
        public static let musicOnVisual = AccessMode("musicOnVisual")

        /// Indicates that the resource contains information encoded in tactile form.
        ///
        /// Note that although an indication of a tactile mode often indicates the content is encoded using a braille
        /// system, this is not always the case. Tactile perception may also indicate, for example, the use of tactile
        /// graphics to convey information.
        public static let tactile = AccessMode("tactile")

        /// Indicates that the resource contains text encoded in visual form.
        public static let textOnVisual = AccessMode("textOnVisual")

        /// Indicates that the resource contains information encoded in textual form.
        public static let textual = AccessMode("textual")

        /// Indicates that the resource contains information encoded in visual form.
        public static let visual = AccessMode("visual")
    }

    public enum PrimaryAccessMode: String, Hashable, Sendable {
        /// Indicates that auditory perception is necessary to consume the information.
        case auditory

        /// Indicates that tactile perception is necessary to consume the information.
        case tactile

        /// Indicates that the ability to read textual content is necessary to consume the information.
        ///
        /// Note that reading textual content does not require visual perception, as textual content can be rendered as
        /// audio using a text-to-speech capable device or assistive technology.
        case textual

        /// Indicates that visual perception is necessary to consume the information.
        case visual
    }

    public struct Feature: Hashable, Sendable {
        public let id: String

        public init(_ id: String) {
            self.id = id
        }

        /// Indicates that the resource does not contain any accessibility features.
        public static let none = Feature("none")

        // Structure and Navigation Terms
        //
        // The structure and navigation term identify structuring and navigation aids that facilitate use of the work.

        /// The work includes annotations from the author, instructor and/or others.
        public static let annotations = Feature("annotations")

        /// Indicates the resource includes ARIA roles to organize and improve the structure and navigation.
        ///
        /// The use of this value corresponds to the inclusion of Document Structure, Landmark, Live Region, and Window
        /// roles [WAI-ARIA].
        public static let aria = Feature("ARIA")

        /// The work includes bookmarks to facilitate navigation to key points.
        @available(*, deprecated, message: "The use of the bookmarks value is now deprecated due to its ambiguity. For PDF bookmarks, the tableOfContents value should be used instead. For bookmarks in ebooks, the annotations value can be used.")
        public static let bookmarks = Feature("bookmarks")

        /// The work includes an index to the content.
        public static let index = Feature("index")

        /// The resource includes static page markers, such as those identified
        /// by the doc-pagebreak role (DPUB-ARIA-1.0).
        ///
        /// This value is most commonly used with ebooks for which there is a
        /// statically paginated equivalent, such as a print edition, but it is
        /// not required that the page markers correspond to another work. The
        /// markers may exist solely to facilitate navigation in purely digital
        /// works.
        public static let pageBreakMarkers = Feature("pageBreakMarkers")

        /// The resource includes a means of navigating to static page break
        /// locations.
        ///
        /// The most common way of providing page navigation in digital
        /// publications is through a page list.
        public static let pageNavigation = Feature("pageNavigation")

        /// The work includes equivalent print page numbers. This setting is
        /// most commonly used with ebooks for which there is a print
        /// equivalent.
        ///
        /// Deprecated for publication authors: https://github.com/readium/go-toolkit/issues/92
        public static let printPageNumbers = Feature("printPageNumbers")

        /// The reading order of the content is clearly defined in the markup (e.g., figures, sidebars and other
        /// secondary content has been marked up to allow it to be skipped automatically and/or manually escaped from.
        public static let readingOrder = Feature("readingOrder")

        /// The use of headings in the work fully and accurately reflects the document hierarchy, allowing navigation by
        /// assistive technologies.
        public static let structuralNavigation = Feature("structuralNavigation")

        /// The work includes a table of contents that provides links to the major sections of the content.
        public static let tableOfContents = Feature("tableOfContents")

        /// The contents of the PDF have been tagged to permit access by assistive technologies.
        public static let taggedPDF = Feature("taggedPDF")

        // Adaptation Terms
        //
        // The adaptation terms identify provisions in the content that enable reading in alternative access modes.

        /// Alternative text is provided for visual content (e.g., via the HTML `alt` attribute).
        public static let alternativeText = Feature("alternativeText")

        /// Audio descriptions are available (e.g., via an HTML `track` element with its `kind` attribute set to
        /// "descriptions").
        public static let audioDescription = Feature("audioDescription")

        /// Indicates that synchronized captions are available for audio and video content.
        @available(*, deprecated, message: "Authors should use the more specific closedCaptions or openCaptions values, as appropriate.")
        public static let captions = Feature("captions")

        /// Indicates that synchronized closed captions are available for audio
        /// and video content.
        ///
        /// Closed captions are defined separately from the video, allowing
        /// users to control whether they are rendered or not, unlike open
        /// captions.
        public static let closedCaptions = Feature("closedCaptions")

        /// Textual descriptions of math equations are included, whether in the alt attribute for image-based equations,
        /// using the `alttext` attribute for MathML equations, or by other means.
        public static let describedMath = Feature("describedMath")

        /// Descriptions are provided for image-based visual content and/or complex structures such as tables,
        /// mathematics, diagrams, and charts.
        public static let longDescription = Feature("longDescription")

        /// Indicates that synchronized open captions are available for audio
        /// and video content.
        ///
        /// Open captions are part of the video stream and cannot be turned off
        /// by the user, unlike closed captions.
        public static let openCaptions = Feature("openCaptions")

        /// Sign language interpretation is available for audio and video content.
        public static let signLanguage = Feature("signLanguage")

        /// Indicates that a transcript of the audio content is available.
        public static let transcript = Feature("transcript")

        // Rendering Control Terms
        //
        // The rendering control values identify that access to a resource and rendering and playback of its content can
        // be controlled for easier reading.

        /// Display properties are controllable by the user. This property can be set, for example, if custom CSS style
        /// sheets can be applied to the content to control the appearance. It can also be used to indicate that styling
        /// in document formats like Word and PDF can be modified.
        public static let displayTransformability = Feature("displayTransformability")

        /// Describes a resource that offers both audio and text, with information that allows them to be rendered
        /// simultaneously. The granularity of the synchronization is not specified. This term is not recommended when
        /// the only material that is synchronized is the document headings.
        public static let synchronizedAudioText = Feature("synchronizedAudioText")

        /// For content with timed interaction, this value indicates that the user can control the timing to meet their
        /// needs (e.g., pause and reset)
        public static let timingControl = Feature("timingControl")

        /// No digital rights management or other content restriction protocols have been applied to the resource.
        public static let unlocked = Feature("unlocked")

        // Specialized Markup Terms
        //
        // The specialized markup terms identify content available in specialized markup grammars. These grammars
        // typically provide users with enhanced structure and navigation capabilities.

        /// Identifies that chemical information is encoded using the ChemML markup language.
        public static let chemML = Feature("ChemML")

        /// Identifies that mathematical equations and formulas are encoded in the LaTeX typesetting system.
        public static let latex = Feature("latex")

        /// Identifies that the LaTeX typesetting system is used to encode
        /// chemical equations and formulas.
        public static let latexChemistry = Feature("latex-chemistry")

        /// Identifies that mathematical equations and formulas are encoded in MathML.
        public static let mathML = Feature("MathML")

        /// Identifies that MathML is used to encode chemical equations and
        /// formulas.
        public static let mathMLChemistry = Feature("MathML-chemistry")

        /// One or more of SSML, Pronunciation-Lexicon, and CSS3-Speech properties has been used to enhance
        /// text-to-speech playback quality.
        public static let ttsMarkup = Feature("ttsMarkup")

        // Clarity Terms
        //
        // The clarity terms identify ways that the content has been enhanced for improved auditory or visual clarity.

        /// Audio content with speech in the foreground meets the contrast thresholds set out in WCAG Success Criteria
        /// 1.4.7.
        public static let highContrastAudio = Feature("highContrastAudio")

        /// Content meets the visual contrast threshold set out in WCAG Success Criteria 1.4.6.
        public static let highContrastDisplay = Feature("highContrastDisplay")

        /// The content has been formatted to meet large print guidelines.
        ///
        /// The property is not set if the font size can be increased. See displayTransformability.
        public static let largePrint = Feature("largePrint")

        // Tactile Terms
        //
        // The tactile terms identify content that is available in tactile form.

        /// The content is in braille format, or alternatives are available in braille.
        public static let braille = Feature("braille")

        /// When used with creative works such as books, indicates that the resource includes tactile graphics.
        /// When used to describe an image resource or physical object, indicates that the resource is a tactile
        /// graphic.
        public static let tactileGraphic = Feature("tactileGraphic")

        /// When used with creative works such as books, indicates that the resource includes models to generate tactile
        /// 3D objects. When used to describe a physical object, indicates that the resource is a tactile 3D object.
        public static let tactileObject = Feature("tactileObject")

        // Internationalization terms
        //
        // The internationalization terms identify those accessibility
        // characteristics of the content which are required for
        // internationalization.

        /// Indicates that ruby annotations JLreq are attached to every CJK
        /// ideographic character in the content. Ruby annotations are used as
        /// pronunciation guides for the logographic characters for languages
        /// like Chinese or Japanese. They make difficult CJK ideographic
        /// characters more accessible.
        public static let fullRubyAnnotations = Feature("fullRubyAnnotations")

        /// Indicates that the content can be laid out horizontally (e.g, using
        /// the horizontal-tb writing mode of css-writing-modes-3). This value
        /// should only be set when the language of the content allows both
        /// horizontal and vertical directions. Notable examples of such
        /// languages are Chinese, Japanese, and Korean.
        public static let horizontalWriting = Feature("horizontalWriting")

        /// Indicates that `ruby` annotations HTML are provided in the content.
        /// Ruby annotations are used as pronunciation guides for the
        /// logographic characters for languages like Chinese or Japanese. It
        /// makes difficult Kanji or CJK ideographic characters more accessible.
        ///
        /// The absence of rubyAnnotations implies that no CJK ideographic
        /// characters have ruby.
        public static let rubyAnnotations = Feature("rubyAnnotations")

        /// Indicates that the content can be laid out vertically (e.g, using
        /// the vertical-rl of [css-writing-modes-3]). This value should only
        /// be set when the language of the content allows both horizontal and
        /// vertical directions.
        public static let verticalWriting = Feature("verticalWriting")

        /// Indicates that the content can be rendered with additional word
        /// segmentation.
        public static let withAdditionalWordSegmentation = Feature("withAdditionalWordSegmentation")

        /// Indicates that the content can be rendered without additional word
        /// segmentation.
        public static let withoutAdditionalWordSegmentation = Feature("withoutAdditionalWordSegmentation")
    }

    public struct Hazard: Hashable, Sendable {
        public let id: String

        public init(_ id: String) {
            self.id = id
        }

        /// Indicates that the resource presents a flashing hazard for photosensitive persons.
        public static let flashing = Hazard("flashing")

        /// Indicates that the resource does not present a flashing hazard.
        public static let noFlashingHazard = Hazard("noFlashingHazard")

        /// Indicates that the author cannot determine if a flashing hazard
        /// exists.
        public static let unknownFlashingHazard = Hazard("unknownFlashingHazard")

        /// Indicates that the resource contains instances of motion simulation
        /// that may affect some individuals.
        ///
        /// Some examples of motion simulation include video games with a
        /// first-person perspective and CSS-controlled backgrounds that move
        /// when a user scrolls a page.
        public static let motionSimulation = Hazard("motionSimulation")

        /// Indicates that the resource does not contain instances of motion simulation.
        public static let noMotionSimulationHazard = Hazard("noMotionSimulationHazard")

        /// Indicates that it is unknown if a motion simulation hazard exists
        /// within the content.
        public static let unknownMotionSimulationHazard = Hazard("unknownMotionSimulationHazard")

        /// Indicates that the resource contains auditory sounds that may affect
        /// some individuals.
        public static let sound = Hazard("sound")

        /// Indicates that the resource does not contain auditory hazards.
        public static let noSoundHazard = Hazard("noSoundHazard")

        /// Indicates that it is unknown if an auditory hazard exists within the
        /// content.
        public static let unknownSoundHazard = Hazard("unknownSoundHazard")

        /// Indicates that the author is not able to determine if the resource
        /// presents any hazards.
        public static let unknown = Hazard("unknown")

        /// Indicates that the resource does not contain any hazards.
        public static let none = Hazard("none")
    }

    /// ``Exemption`` allows content creators to identify publications that do
    /// not meet conformance requirements but fall under exemptions in a given
    /// juridiction.
    ///
    /// While this list is currently limited to exemptions covered by the
    /// European Accessibility Act, it will be extended to cover additional
    /// exemptions in the future.
    public struct Exemption: Hashable, Sendable {
        public let id: String

        public init(_ id: String) {
            self.id = id
        }

        /// Article 14, paragraph 1 of the European Accessibility Act states
        /// that its accessibility requirements shall apply only to the extent
        /// that compliance: … (b) does not result in the imposition of a
        /// disproportionate burden on the economic operators concerned
        /// https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32019L0882#d1e2148-70-1
        public static let eaaDisproportionateBurden = Exemption("eaa-disproportionate-burden")

        /// Article 14, paragraph 1 of the European Accessibility Act states
        /// that its accessibility requirements shall apply only to the extent
        /// that compliance: (a) does not require a significant change in a
        /// product or service that results in the fundamental alteration of its
        /// basic nature
        /// https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32019L0882#d1e2148-70-1
        public static let eaaFundamentalAlteration = Exemption("eaa-fundamental-alteration")

        /// The European Accessibility Act defines a microenterprise as: an
        /// enterprise which employs fewer than 10 persons and which has an
        /// annual turnover not exceeding EUR 2 million or an annual balance
        /// sheet total not exceeding EUR 2 million.
        ///
        /// It further states in Article 4, paragraph 5: Microenterprises
        /// providing services shall be exempt from complying with the
        /// accessibility requirements referred to in paragraph 3 of this
        /// Article and any obligations relating to the compliance with those
        /// requirements.
        /// https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32019L0882#d1e1798-70-1
        public static let eaaMicroenterprise = Exemption("eaa-microenterprise")
    }

    public init(
        conformsTo: [Profile] = [],
        certification: Certification? = nil,
        summary: String? = nil,
        accessModes: [AccessMode] = [],
        accessModesSufficient: [[PrimaryAccessMode]] = [],
        features: [Feature] = [],
        hazards: [Hazard] = [],
        exemptions: [Exemption] = []
    ) {
        self.conformsTo = conformsTo
        self.certification = certification
        self.summary = summary
        self.accessModes = accessModes
        self.accessModesSufficient = accessModesSufficient
        self.features = features
        self.hazards = hazards
        self.exemptions = exemptions
    }

    public init?(json: Any?, warnings: WarningLogger? = nil) throws {
        guard json != nil else {
            return nil
        }
        guard let jsonObject = json as? [String: Any] else {
            warnings?.log("Invalid Accessibility object", model: Self.self, source: json, severity: .moderate)
            throw JSONError.parsing(Self.self)
        }

        self.init(
            conformsTo: (parseArray(jsonObject["conformsTo"], allowingSingle: true) as [String])
                .map(Profile.init),
            certification: (jsonObject["certification"] as? [String: Any])
                .map {
                    Certification(
                        certifiedBy: $0["certifiedBy"] as? String,
                        credential: $0["credential"] as? String,
                        report: $0["report"] as? String
                    )
                }
                .takeIf { $0.certifiedBy != nil || $0.credential != nil || $0.report != nil },
            summary: jsonObject["summary"] as? String,
            accessModes: parseArray(jsonObject["accessMode"]).map(AccessMode.init),
            accessModesSufficient: (jsonObject["accessModeSufficient"] as? [Any] ?? [])
                .map { json -> [Accessibility.PrimaryAccessMode] in
                    if let str = json as? String, let value = PrimaryAccessMode(rawValue: str) {
                        return [value]
                    } else if let strs = json as? [String] {
                        return strs.compactMap(PrimaryAccessMode.init(rawValue:))
                    } else {
                        return []
                    }
                }
                .filter { !$0.isEmpty },
            features: parseArray(jsonObject["feature"]).map(Feature.init),
            hazards: parseArray(jsonObject["hazard"]).map(Hazard.init),
            exemptions: parseArray(jsonObject["exemption"]).map(Exemption.init)
        )
    }

    public var json: [String: Any] {
        makeJSON([
            "conformsTo": encodeIfNotEmpty(conformsTo.map(\.uri)),
            "certification": encodeIfNotEmpty(certification.map {
                makeJSON([
                    "certifiedBy": encodeIfNotNil($0.certifiedBy),
                    "credential": encodeIfNotNil($0.credential),
                    "report": encodeIfNotNil($0.report),
                ])
            }),
            "summary": encodeIfNotNil(summary),
            "accessMode": encodeIfNotEmpty(accessModes.map(\.id)),
            "accessModeSufficient": encodeIfNotEmpty(accessModesSufficient.map { $0.map(\.rawValue) }),
            "feature": encodeIfNotEmpty(features.map(\.id)),
            "hazard": encodeIfNotEmpty(hazards.map(\.id)),
            "exemption": encodeIfNotEmpty(exemptions.map(\.id)),
        ])
    }
}
