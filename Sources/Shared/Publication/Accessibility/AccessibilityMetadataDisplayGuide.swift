//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal
import SwiftUI

/// When presenting accessibility metadata provided by the publisher, it is
/// suggested that the section is introduced using terms such as "claims" or
/// "declarations" (e.g., "Accessibility Claims").
public struct AccessibilityMetadataDisplayGuide {
    /// The ways of reading display field is a banner heading that groups
    /// together the following information about how the content facilitates
    /// access.
    public var waysOfReading: WaysOfReading

    /// Identifies the navigation features included in the publication.
    public var navigation: Navigation

    /// Indicates the presence of math, chemical formulas, extended descriptions
    /// for information rich images, e.g., charts, diagrams, figures, graphs,
    /// and whether these are in an accessible format or available in an
    /// alternative form, e.g., whether math and chemical formulas are navigable
    /// with assistive technologies, or whether extended descriptions are
    /// available for information-rich images. In addition, it indicates the
    /// presence of videos and if closed captions, open captions, or transcripts
    /// for prerecorded audio are available.
    public var richContent: RichContent

    /// This section lists additional metadata categories that can help users
    /// better understand the accessibility characteristics of digital
    /// publications. These are for metadata that do not fit into the other
    /// categories or are rarely used in trade publishing.
    public var additionalInformation: AdditionalInformation

    /// Identifies any potential hazards (e.g., flashing elements, sounds, and
    /// motion simulation) that could afflict physiologically sensitive users.
    public var hazards: Hazards

    /// Identifies whether the digital publication claims to meet
    /// internationally recognized conformance standards for accessibility.
    public var conformance: Conformance

    /// In some jurisdictions publishers may be able to claim an exemption from
    /// the provision of accessible publications, including the provision of
    /// accessibility metadata. This should always be subject to clarification
    /// by legal counsel for each jurisdiction.
    public var legal: Legal

    /// The accessibility summary was intended (in EPUB Accessibility 1.0) to
    /// describe in human-readable prose the accessibility features present in
    /// the publication as well as any shortcomings. Starting with EPUB
    /// Accessibility version 1.1 the accessibility summary became a human-
    /// readable summary of the accessibility that complements, but does not
    /// duplicate, the other discoverability metadata.
    public var accessibilitySummary: AccessibilitySummary

    /// Returns the list of display fields in their recommended order.
    public var fields: [AccessibilityDisplayField] {
        [
            waysOfReading,
            navigation,
            richContent,
            additionalInformation,
            hazards,
            conformance,
            legal,
            accessibilitySummary,
        ]
    }

    /// The ways of reading display field is a banner heading that groups
    /// together the following information about how the content facilitates
    /// access.
    ///
    /// https://w3c.github.io/publ-a11y/a11y-meta-display-guide/2.0/guidelines/#ways-of-reading
    public struct WaysOfReading: AccessibilityDisplayField {
        /// Indicates if users can modify the appearance of the text and the
        /// page layout according to the possibilities offered by the reading
        /// system.
        public var visualAdjustments: VisualAdjustments = .unknown

        /// Indicates whether all content required for comprehension can be
        /// consumed in text and therefore is available to reading systems with
        /// read aloud speech or dynamic braille capabilities.
        public var nonvisualReading: NonvisualReading = .noMetadata

        /// Indicates whether text alternatives are provided for visuals.
        public var nonvisualReadingAltText: Bool = false

        /// Indicates the presence of prerecorded audio and specifies if this
        /// audio is standalone (an audiobook), is an alternative to the text
        /// (synchronized text with audio playback), or is complementary audio
        /// (portions of audio, (e.g., reading of a poem).
        public var prerecordedAudio: PrerecordedAudio = .noMetadata

        public var localizedTitle: String { bundleString("ways-of-reading-title") }

        /// "Ways of reading" should be rendered even if there is no metadata.
        public let shouldDisplay: Bool = true

        public enum VisualAdjustments {
            /// Appearance can be modified
            case modifiable

            /// Appearance cannot be modified
            case unmodifiable

            /// No information about appearance modifiability is available
            case unknown
        }

        public enum NonvisualReading {
            /// Readable in read aloud or dynamic braille
            case readable

            /// Not fully readable in read aloud or dynamic braille
            case notFully

            /// Not readable in read aloud or dynamic braille
            case unreadable

            /// No information about nonvisual reading is available
            case noMetadata
        }

        public enum PrerecordedAudio {
            /// Prerecorded audio synchronized with text
            case synchronized

            /// Prerecorded audio only
            case audioOnly

            /// Prerecorded audio clips
            case audioComplementary

            /// No information about prerecorded audio is available
            case noMetadata
        }

        public var statements: [AccessibilityDisplayStatement] {
            Array {
                switch visualAdjustments {
                case .modifiable:
                    $0.append(.waysOfReadingVisualAdjustmentsModifiable)
                case .unmodifiable:
                    $0.append(.waysOfReadingVisualAdjustmentsUnmodifiable)
                case .unknown:
                    $0.append(.waysOfReadingVisualAdjustmentsUnknown)
                }

                switch nonvisualReading {
                case .readable:
                    $0.append(.waysOfReadingNonvisualReadingReadable)
                case .notFully:
                    $0.append(.waysOfReadingNonvisualReadingNotFully)
                case .unreadable:
                    $0.append(.waysOfReadingNonvisualReadingNone)
                case .noMetadata:
                    $0.append(.waysOfReadingNonvisualReadingNoMetadata)
                }

                if nonvisualReadingAltText {
                    $0.append(.waysOfReadingNonvisualReadingAltText)
                }

                switch prerecordedAudio {
                case .synchronized:
                    $0.append(.waysOfReadingPrerecordedAudioSynchronized)
                case .audioOnly:
                    $0.append(.waysOfReadingPrerecordedAudioOnly)
                case .audioComplementary:
                    $0.append(.waysOfReadingPrerecordedAudioComplementary)
                case .noMetadata:
                    $0.append(.waysOfReadingPrerecordedAudioNoMetadata)
                }
            }
        }
    }

    /// Identifies the navigation features included in the publication.
    ///
    /// https://w3c.github.io/publ-a11y/a11y-meta-display-guide/2.0/guidelines/#navigation
    public struct Navigation: AccessibilityDisplayField {
        /// Indicates whether no information about navigation features is
        /// available.
        public var noMetadata: Bool = true

        /// Table of contents to all chapters of the text via links.
        public var tableOfContents: Bool = false

        /// Index with links to referenced entries.
        public var index: Bool = false

        /// Elements such as headings, tables, etc for structured navigation.
        public var headings: Bool = false

        /// Page list to go to pages from the print source version.
        public var page: Bool = false

        public var localizedTitle: String { bundleString("navigation-title") }

        public var shouldDisplay: Bool { !noMetadata }

        public var statements: [AccessibilityDisplayStatement] {
            Array {
                guard !noMetadata else {
                    $0.append(.navigationNoMetadata)
                    return
                }

                if tableOfContents {
                    $0.append(.navigationTOC)
                }
                if index {
                    $0.append(.navigationIndex)
                }
                if headings {
                    $0.append(.navigationStructural)
                }
                if page {
                    $0.append(.navigationPageNavigation)
                }
            }
        }
    }

    /// Identifies whether the digital publication claims to meet
    /// internationally recognized conformance standards for accessibility.
    ///
    /// https://w3c.github.io/publ-a11y/a11y-meta-display-guide/2.0/guidelines/#conformance-group
    public struct Conformance: AccessibilityDisplayField {
        /// Accessibility conformance profile.
        public var profile: Accessibility.Profile?

        public var localizedTitle: String { bundleString("conformance-title") }

        /// "Conformance" should be rendered even if there is no metadata.
        public let shouldDisplay: Bool = true

        public var statements: [AccessibilityDisplayStatement] {
            Array {
                guard let profile = profile else {
                    $0.append(.conformanceNo)
                    return
                }

                if profile.isWCAGLevelAAA {
                    $0.append(.conformanceAAA)
                } else if profile.isWCAGLevelAA {
                    $0.append(.conformanceAA)
                } else if profile.isWCAGLevelA {
                    $0.append(.conformanceA)
                } else {
                    $0.append(.conformanceUnknownStandard)
                }

                // FIXME: Waiting on W3C to offer localized strings with placeholders instead of concatenation. See https://github.com/w3c/publ-a11y/issues/688
                // FIXME: Details? + Certification date is missing from RWPM
//                if let certification = certification {
//                    if let certifier = certification.certifiedBy {
//                        $0.append(.conformanceCertifier, appending: certifier)
//                    }
//                    if let credential = certification.credential {
//                        $0.append(.conformanceCertifierCredentials, appending: credential)
//                    }
//                }
            }
        }
    }

    /// Indicates the presence of math, chemical formulas, extended descriptions
    /// for information rich images, e.g., charts, diagrams, figures, graphs,
    /// and whether these are in an accessible format or available in an
    /// alternative form, e.g., whether math and chemical formulas are navigable
    /// with assistive technologies, or whether extended descriptions are
    /// available for information-rich images. In addition, it indicates the
    /// presence of videos and if closed captions, open captions, or transcripts
    /// for prerecorded audio are available.
    ///
    /// https://w3c.github.io/publ-a11y/a11y-meta-display-guide/2.0/guidelines/#rich-content
    public struct RichContent: AccessibilityDisplayField {
        /// Indicates whether no information about rich content is available.
        public var noMetadata: Bool = true

        /// Information-rich images are described by extended descriptions.
        public var extendedAltTextDescriptions: Bool = false

        /// Text descriptions of math are provided.
        public var mathFormula: Bool = false

        /// Math formulas in accessible format (MathML).
        public var mathFormulaAsMathML: Bool = false

        /// Math formulas in accessible format (LaTeX).
        public var mathFormulaAsLaTeX: Bool = false

        /// Chemical formulas in accessible format (MathML).
        public var chemicalFormulaAsMathML: Bool = false

        /// Chemical formulas in accessible format (LaTeX).
        public var chemicalFormulaAsLaTeX: Bool = false

        /// Videos included in publications have closed captions.
        public var closedCaptions: Bool = false

        /// Videos included in publications have open captions.
        public var openCaptions: Bool = false

        /// Transcript(s) provided.
        public var transcript: Bool = false

        public var localizedTitle: String { bundleString("rich-content-title") }

        public var shouldDisplay: Bool { !noMetadata }

        public var statements: [AccessibilityDisplayStatement] {
            Array {
                guard !noMetadata else {
                    $0.append(.richContentUnknown)
                    return
                }

                if extendedAltTextDescriptions {
                    $0.append(.richContentExtended)
                }
                if mathFormula {
                    $0.append(.richContentAccessibleMathDescribed)
                }
                if mathFormulaAsMathML {
                    $0.append(.richContentAccessibleMathAsMathML)
                }
                if mathFormulaAsLaTeX {
                    $0.append(.richContentAccessibleMathAsLaTeX)
                }
                if chemicalFormulaAsMathML {
                    $0.append(.richContentAccessibleChemistryAsMathML)
                }
                if chemicalFormulaAsLaTeX {
                    $0.append(.richContentAccessibleChemistryAsLaTeX)
                }
                if closedCaptions {
                    $0.append(.richContentClosedCaptions)
                }
                if openCaptions {
                    $0.append(.richContentOpenCaptions)
                }
                if transcript {
                    $0.append(.richContentTranscript)
                }
            }
        }
    }

    /// Identifies any potential hazards (e.g., flashing elements, sounds, and
    /// motion simulation) that could afflict physiologically sensitive users.
    ///
    /// Unlike other accessibility properties, the presence of hazards can
    /// be expressed either positively or negatively. This is because users
    /// search for content that is safe for them as well as want to know
    /// when content is potentially dangerous to them.
    ///
    /// https://w3c.github.io/publ-a11y/a11y-meta-display-guide/2.0/guidelines/#hazards
    public struct Hazards: AccessibilityDisplayField {
        public enum Hazard {
            case yes
            case no
            case unknown
            case noMetadata
        }

        /// Indicates whether no information about rich content is available.
        public var noMetadata: Bool {
            flashing == .noMetadata && motion == .noMetadata && sounds == .noMetadata
        }

        /// The publication contains no hazards.
        public var noHazards: Bool {
            flashing == .no && motion == .no && sounds == .no
        }

        /// The presence of hazards is unknown.
        public var unknown: Bool {
            flashing == .unknown && motion == .unknown && sounds == .unknown
        }

        /// The publication contains flashing content which can cause
        /// photosensitive seizures.
        public var flashing: Hazard = .noMetadata

        /// The publication contains motion simulations that can cause motion
        /// sickness.
        public var motion: Hazard = .noMetadata

        /// The publication contains sounds which can be uncomfortable.
        public var sounds: Hazard = .noMetadata

        public var localizedTitle: String { bundleString("hazards-title") }

        public var shouldDisplay: Bool { !noMetadata }

        public var statements: [AccessibilityDisplayStatement] {
            Array {
                if noHazards {
                    $0.append(.hazardsNone)
                } else if unknown {
                    $0.append(.hazardsUnknown)
                } else if noMetadata {
                    $0.append(.hazardsNoMetadata)
                } else {
                    if flashing == .yes {
                        $0.append(.hazardsFlashing)
                    }
                    if motion == .yes {
                        $0.append(.hazardsMotion)
                    }
                    if sounds == .yes {
                        $0.append(.hazardsSound)
                    }
                    if flashing == .unknown {
                        $0.append(.hazardsFlashingUnknown)
                    }
                    if motion == .unknown {
                        $0.append(.hazardsMotionUnknown)
                    }
                    if sounds == .unknown {
                        $0.append(.hazardsSoundUnknown)
                    }
                    if flashing == .no {
                        $0.append(.hazardsFlashingNone)
                    }
                    if motion == .no {
                        $0.append(.hazardsMotionNone)
                    }
                    if sounds == .no {
                        $0.append(.hazardsSoundNone)
                    }
                }
            }
        }
    }

    /// The accessibility summary was intended (in EPUB Accessibility 1.0) to
    /// describe in human-readable prose the accessibility features present in
    /// the publication as well as any shortcomings. Starting with EPUB
    /// Accessibility version 1.1 the accessibility summary became a human-
    /// readable summary of the accessibility that complements, but does not
    /// duplicate, the other discoverability metadata.
    ///
    /// https://w3c.github.io/publ-a11y/a11y-meta-display-guide/2.0/guidelines/#accessibility-summary
    public struct AccessibilitySummary: AccessibilityDisplayField {
        public var summary: String? = nil

        public var localizedTitle: String { bundleString("accessibility-summary-title") }

        public var shouldDisplay: Bool { summary != nil }

        public var statements: [AccessibilityDisplayStatement] {
            Array {
                if let summary = summary {
                    let summary = NSAttributedString(string: summary)
                    $0.append(AccessibilityDisplayStatement(
                        key: .accessibilitySummary,
                        compactLocalizedString: { summary },
                        descriptiveLocalizedString: { summary }
                    ))
                } else {
                    $0.append(.accessibilitySummaryNoMetadata)
                }
            }
        }
    }

    /// In some jurisdictions publishers may be able to claim an exemption from
    /// the provision of accessible publications, including the provision of
    /// accessibility metadata. This should always be subject to clarification
    /// by legal counsel for each jurisdiction.
    ///
    /// https://w3c.github.io/publ-a11y/a11y-meta-display-guide/2.0/guidelines/#legal-considerations
    public struct Legal: AccessibilityDisplayField {
        /// No information is available.
        public var noMetadata: Bool = true

        /// This publication claims an accessibility exemption in some
        /// jurisdictions.
        public var exemption: Bool = false

        public var localizedTitle: String { bundleString("legal-considerations-title") }

        public var shouldDisplay: Bool { !noMetadata }

        public var statements: [AccessibilityDisplayStatement] {
            Array {
                if exemption {
                    $0.append(.legalConsiderationsExempt)
                } else {
                    $0.append(.legalConsiderationsNoMetadata)
                }
            }
        }
    }

    /// This section lists additional metadata categories that can help users
    /// better understand the accessibility characteristics of digital
    /// publications. These are for metadata that do not fit into the other
    /// categories or are rarely used in trade publishing.
    public struct AdditionalInformation: AccessibilityDisplayField {
        /// No information is available.
        public var noMetadata: Bool = true

        /// Page breaks included.
        public var pageBreakMarkers: Bool = false

        /// ARIA roles included.
        public var aria: Bool = false

        /// Audio descriptions.
        public var audioDescriptions: Bool = false

        /// Braille.
        public var braille: Bool = false

        /// Some ruby annotations.
        public var someRubyAnnotations: Bool = false

        /// Full ruby annotations
        public var fullRubyAnnotations: Bool = false

        /// High contrast between foreground and background audio
        public var highAudioContrast: Bool = false

        /// High contrast between foreground text and background.
        public var highColorContrast: Bool = false

        /// Large print.
        public var largePrint: Bool = false

        /// Sign language.
        public var signLanguage: Bool = false

        /// Tactile graphics included.
        public var tactileGraphics: Bool = false

        /// Tactile 3D objects.
        public var tactileObjects: Bool = false

        /// Text-to-speech hinting provided.
        public var textToSpeechHinting: Bool = false

        public var localizedTitle: String { bundleString("additional-accessibility-information-title") }

        public var shouldDisplay: Bool { !noMetadata }

        public var statements: [AccessibilityDisplayStatement] {
            Array {
                if pageBreakMarkers {
                    $0.append(.additionalAccessibilityInformationPageBreaks)
                }
                if aria {
                    $0.append(.additionalAccessibilityInformationARIA)
                }
                if audioDescriptions {
                    $0.append(.additionalAccessibilityInformationAudioDescriptions)
                }
                if braille {
                    $0.append(.additionalAccessibilityInformationBraille)
                }
                if someRubyAnnotations {
                    $0.append(.additionalAccessibilityInformationRubyAnnotations)
                }
                if fullRubyAnnotations {
                    $0.append(.additionalAccessibilityInformationFullRubyAnnotations)
                }
                if highAudioContrast {
                    $0.append(.additionalAccessibilityInformationHighContrastBetweenForegroundAndBackgroundAudio)
                }
                if highColorContrast {
                    $0.append(.additionalAccessibilityInformationHighContrastBetweenTextAndBackground)
                }
                if largePrint {
                    $0.append(.additionalAccessibilityInformationLargePrint)
                }
                if signLanguage {
                    $0.append(.additionalAccessibilityInformationSignLanguage)
                }
                if tactileGraphics {
                    $0.append(.additionalAccessibilityInformationTactileGraphics)
                }
                if tactileObjects {
                    $0.append(.additionalAccessibilityInformationTactileObjects)
                }
                if textToSpeechHinting {
                    $0.append(.additionalAccessibilityInformationTextToSpeechHinting)
                }
            }
        }
    }
}

/// Represents a collection of related accessibility claims which should be
/// displayed together in a section
public protocol AccessibilityDisplayField {
    /// Localized title for this display field, for example to use as a
    /// section header.
    var localizedTitle: String { get }

    /// List of accessibility claims to display for this field.
    var statements: [AccessibilityDisplayStatement] { get }

    /// Indicates whether this display field should be rendered in the user
    /// interface, because it contains useful information.
    ///
    /// A field with `shouldDisplay` set to `false` might have for only
    /// statement "No information is available".
    var shouldDisplay: Bool { get }
}

/// Represents a single accessibility claim, such as "Appearance can be
/// modified".
public struct AccessibilityDisplayStatement {
    /// Key ID identifying the statement.
    /// See https://w3c.github.io/publ-a11y/a11y-meta-display-guide/2.0/draft/localizations/
    public let key: Key

    /// A localized representation for this display statement.
    ///
    /// For example:
    /// - compact: Appearance can be modified
    /// - descriptive: For example, "Appearance of the text and page layout can
    ///   be modified according to the capabilities of the reading system (font
    ///   family and font size, spaces between paragraphs, sentences, words, and
    ///   letters, as well as color of background and text)
    ///
    /// Some statements contain HTTP links; so we use an ``NSAttributedString``.
    ///
    /// - Parameter descriptive: When true, will return the long descriptive
    ///   statement.
    public func localizedString(descriptive: Bool) -> NSAttributedString {
        if descriptive {
            return descriptiveLocalizedString()
        } else {
            return compactLocalizedString()
        }
    }

    init(
        key: Key,
        compactLocalizedString: @escaping () -> NSAttributedString,
        descriptiveLocalizedString: @escaping () -> NSAttributedString
    ) {
        self.key = key
        self.compactLocalizedString = compactLocalizedString
        self.descriptiveLocalizedString = descriptiveLocalizedString
    }

    init(key: Key) {
        self.key = key
        compactLocalizedString = { key.localizedString(descriptive: false) }
        descriptiveLocalizedString = { key.localizedString(descriptive: true) }
    }

    private let compactLocalizedString: () -> NSAttributedString
    private let descriptiveLocalizedString: () -> NSAttributedString

    public struct Key: RawRepresentable, ExpressibleByStringLiteral, Hashable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(stringLiteral value: StringLiteralType) {
            self.init(rawValue: value)
        }

        /// A localized statement for this key.
        ///
        /// For example:
        /// - compact: Appearance can be modified
        /// - descriptive: For example, "Appearance of the text and page layout
        ///   can be modified according to the capabilities of the reading
        ///   system (font family and font size, spaces between paragraphs,
        ///   sentences, words, and letters, as well as color of background and
        ///   text)
        ///
        /// - Parameter descriptive: When true, will return the long descriptive
        ///   statement.
        func localizedString(descriptive: Bool) -> NSAttributedString {
            NSAttributedString(string: bundleString("\(rawValue)-\(descriptive ? "descriptive" : "compact")"))
        }

        public static let waysOfReadingNonvisualReadingAltText: Self = "ways-of-reading-nonvisual-reading-alt-text"
        public static let waysOfReadingNonvisualReadingNoMetadata: Self = "ways-of-reading-nonvisual-reading-no-metadata"
        public static let waysOfReadingNonvisualReadingNone: Self = "ways-of-reading-nonvisual-reading-none"
        public static let waysOfReadingNonvisualReadingNotFully: Self = "ways-of-reading-nonvisual-reading-not-fully"
        public static let waysOfReadingNonvisualReadingReadable: Self = "ways-of-reading-nonvisual-reading-readable"
        public static let waysOfReadingPrerecordedAudioComplementary: Self = "ways-of-reading-prerecorded-audio-complementary"
        public static let waysOfReadingPrerecordedAudioNoMetadata: Self = "ways-of-reading-prerecorded-audio-no-metadata"
        public static let waysOfReadingPrerecordedAudioOnly: Self = "ways-of-reading-prerecorded-audio-only"
        public static let waysOfReadingPrerecordedAudioSynchronized: Self = "ways-of-reading-prerecorded-audio-synchronized"
        public static let waysOfReadingVisualAdjustmentsModifiable: Self = "ways-of-reading-visual-adjustments-modifiable"
        public static let waysOfReadingVisualAdjustmentsUnknown: Self = "ways-of-reading-visual-adjustments-unknown"
        public static let waysOfReadingVisualAdjustmentsUnmodifiable: Self = "ways-of-reading-visual-adjustments-unmodifiable"
        public static let conformanceA: Self = "conformance-a"
        public static let conformanceAA: Self = "conformance-aa"
        public static let conformanceAAA: Self = "conformance-aaa"
        public static let conformanceCertifier: Self = "conformance-certifier"
        public static let conformanceCertifierCredentials: Self = "conformance-certifier-credentials"
        public static let conformanceDetailsCertificationInfo: Self = "conformance-details-certification-info"
        public static let conformanceDetailsCertifierReport: Self = "conformance-details-certifier-report"
        public static let conformanceDetailsClaim: Self = "conformance-details-claim"
        public static let conformanceDetailsEpubAccessibility10: Self = "conformance-details-epub-accessibility-1-0"
        public static let conformanceDetailsEpubAccessibility11: Self = "conformance-details-epub-accessibility-1-1"
        public static let conformanceDetailsLevelA: Self = "conformance-details-level-a"
        public static let conformanceDetailsLevelAA: Self = "conformance-details-level-aa"
        public static let conformanceDetailsLevelAAA: Self = "conformance-details-level-aaa"
        public static let conformanceDetailsWCAG20: Self = "conformance-details-wcag-2-0"
        public static let conformanceDetailsWCAG21: Self = "conformance-details-wcag-2-1"
        public static let conformanceDetailsWCAG22: Self = "conformance-details-wcag-2-2"
        public static let conformanceNo: Self = "conformance-no"
        public static let conformanceUnknownStandard: Self = "conformance-unknown-standard"
        public static let navigationIndex: Self = "navigation-index"
        public static let navigationNoMetadata: Self = "navigation-no-metadata"
        public static let navigationPageNavigation: Self = "navigation-page-navigation"
        public static let navigationStructural: Self = "navigation-structural"
        public static let navigationTOC: Self = "navigation-toc"
        public static let richContentAccessibleChemistryAsLaTeX: Self = "rich-content-accessible-chemistry-as-latex"
        public static let richContentAccessibleChemistryAsMathML: Self = "rich-content-accessible-chemistry-as-mathml"
        public static let richContentAccessibleMathAsLaTeX: Self = "rich-content-accessible-math-as-latex"
        public static let richContentAccessibleMathAsMathML: Self = "rich-content-accessible-math-as-mathml"
        public static let richContentAccessibleMathDescribed: Self = "rich-content-accessible-math-described"
        public static let richContentClosedCaptions: Self = "rich-content-closed-captions"
        public static let richContentExtended: Self = "rich-content-extended"
        public static let richContentOpenCaptions: Self = "rich-content-open-captions"
        public static let richContentTranscript: Self = "rich-content-transcript"
        public static let richContentUnknown: Self = "rich-content-unknown"
        public static let hazardsFlashing: Self = "hazards-flashing"
        public static let hazardsFlashingNone: Self = "hazards-flashing-none"
        public static let hazardsFlashingUnknown: Self = "hazards-flashing-unknown"
        public static let hazardsMotion: Self = "hazards-motion"
        public static let hazardsMotionNone: Self = "hazards-motion-none"
        public static let hazardsMotionUnknown: Self = "hazards-motion-unknown"
        public static let hazardsNoMetadata: Self = "hazards-no-metadata"
        public static let hazardsNone: Self = "hazards-none"
        public static let hazardsSound: Self = "hazards-sound"
        public static let hazardsSoundNone: Self = "hazards-sound-none"
        public static let hazardsSoundUnknown: Self = "hazards-sound-unknown"
        public static let hazardsUnknown: Self = "hazards-unknown"
        public static let accessibilitySummary: Self = "accessibility-summary"
        public static let accessibilitySummaryNoMetadata: Self = "accessibility-summary-no-metadata"
        public static let legalConsiderationsExempt: Self = "legal-considerations-exempt"
        public static let legalConsiderationsNoMetadata: Self = "legal-considerations-no-metadata"
        public static let additionalAccessibilityInformationARIA: Self = "additional-accessibility-information-aria"
        public static let additionalAccessibilityInformationAudioDescriptions: Self = "additional-accessibility-information-audio-descriptions"
        public static let additionalAccessibilityInformationBraille: Self = "additional-accessibility-information-braille"
        public static let additionalAccessibilityInformationColorNotSoleMeansOfConveyingInformation: Self = "additional-accessibility-information-color-not-sole-means-of-conveying-information"
        public static let additionalAccessibilityInformationDyslexiaReadability: Self = "additional-accessibility-information-dyslexia-readability"
        public static let additionalAccessibilityInformationFullRubyAnnotations: Self = "additional-accessibility-information-full-ruby-annotations"
        public static let additionalAccessibilityInformationHighContrastBetweenForegroundAndBackgroundAudio: Self = "additional-accessibility-information-high-contrast-between-foreground-and-background-audio"
        public static let additionalAccessibilityInformationHighContrastBetweenTextAndBackground: Self = "additional-accessibility-information-high-contrast-between-text-and-background"
        public static let additionalAccessibilityInformationLargePrint: Self = "additional-accessibility-information-large-print"
        public static let additionalAccessibilityInformationPageBreaks: Self = "additional-accessibility-information-page-breaks"
        public static let additionalAccessibilityInformationRubyAnnotations: Self = "additional-accessibility-information-ruby-annotations"
        public static let additionalAccessibilityInformationSignLanguage: Self = "additional-accessibility-information-sign-language"
        public static let additionalAccessibilityInformationTactileGraphics: Self = "additional-accessibility-information-tactile-graphics"
        public static let additionalAccessibilityInformationTactileObjects: Self = "additional-accessibility-information-tactile-objects"
        public static let additionalAccessibilityInformationTextToSpeechHinting: Self = "additional-accessibility-information-text-to-speech-hinting"
        public static let additionalAccessibilityInformationUltraHighContrastBetweenTextAndBackground: Self = "additional-accessibility-information-ultra-high-contrast-between-text-and-background"
        public static let additionalAccessibilityInformationVisiblePageNumbering: Self = "additional-accessibility-information-visible-page-numbering"
        public static let additionalAccessibilityInformationWithoutBackgroundSounds: Self = "additional-accessibility-information-without-background-sounds"
    }
}

private func bundleString(_ key: String, _ values: CVarArg...) -> String {
    bundleString("readium.a11y.\(key)", in: Bundle.module, table: "W3CAccessibilityMetadataDisplayGuide", values)
}

/// Returns the localized string in the main bundle, or fallback on the given
/// bundle if not found.
private func bundleString(_ key: String, in bundle: Bundle, table: String? = nil, _ values: [CVarArg]) -> String {
    let defaultValue = bundle.localizedString(forKey: key, value: nil, table: table)
    var string = Bundle.main.localizedString(forKey: key, value: defaultValue, table: nil)
    if !values.isEmpty {
        string = String(format: string, locale: .current, arguments: values)
    }
    return string
}

// Syntactic sugar
private extension Array where Element == AccessibilityDisplayStatement {
    mutating func append(_ key: AccessibilityDisplayStatement.Key) {
        append(AccessibilityDisplayStatement(key: key))
    }
}
