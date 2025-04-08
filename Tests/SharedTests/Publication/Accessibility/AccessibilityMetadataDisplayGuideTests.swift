//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class AccessibilityMetadataDisplayGuideTests: XCTestCase {
    func testDisplayStatementLocalizedString() {
        let statement = AccessibilityDisplayStatement(key: .waysOfReadingNonvisualReadingReadable)

        XCTAssertEqual(
            statement.localizedString(descriptive: false).string,
            "Readable in read aloud or dynamic braille"
        )
        XCTAssertEqual(
            statement.localizedString(descriptive: true).string,
            "All content can be read as read aloud speech or dynamic braille"
        )
    }

    func testDisplayStatementCustomLocalizedString() {
        let statement = AccessibilityDisplayStatement(
            key: .waysOfReadingNonvisualReadingReadable,
            compactLocalizedString: { NSAttributedString(string: "Compact") },
            descriptiveLocalizedString: { NSAttributedString(string: "Descriptive") },
        )

        XCTAssertEqual(
            statement.localizedString(descriptive: false).string,
            "Compact"
        )
        XCTAssertEqual(
            statement.localizedString(descriptive: true).string,
            "Descriptive"
        )
    }

    func testWaysOfReadingTitle() {
        XCTAssertEqual(AccessibilityMetadataDisplayGuide.WaysOfReading().localizedTitle, "Ways of reading")
    }

    func testWaysOfReadingShouldDisplay() {
        // WaysOfReading should always be displayed
        XCTAssertTrue(AccessibilityMetadataDisplayGuide.WaysOfReading(
            visualAdjustments: .unknown,
            nonvisualReading: .noMetadata,
            nonvisualReadingAltText: false,
            prerecordedAudio: .noMetadata
        ).shouldDisplay)
    }

    func testWaysOfReadingStatements() {
        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.WaysOfReading(
                visualAdjustments: .unknown,
                nonvisualReading: .noMetadata,
                nonvisualReadingAltText: true,
                prerecordedAudio: .noMetadata
            ).statements.map(\.key),
            [
                .waysOfReadingVisualAdjustmentsUnknown,
                .waysOfReadingNonvisualReadingNoMetadata,
                .waysOfReadingNonvisualReadingAltText,
                .waysOfReadingPrerecordedAudioNoMetadata,
            ]
        )

        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.WaysOfReading(
                visualAdjustments: .modifiable,
                nonvisualReading: .readable,
                nonvisualReadingAltText: false,
                prerecordedAudio: .synchronized
            ).statements.map(\.key),
            [
                .waysOfReadingVisualAdjustmentsModifiable,
                .waysOfReadingNonvisualReadingReadable,
                .waysOfReadingPrerecordedAudioSynchronized,
            ]
        )

        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.WaysOfReading(
                visualAdjustments: .unmodifiable,
                nonvisualReading: .notFully,
                nonvisualReadingAltText: false,
                prerecordedAudio: .audioOnly
            ).statements.map(\.key),
            [
                .waysOfReadingVisualAdjustmentsUnmodifiable,
                .waysOfReadingNonvisualReadingNotFully,
                .waysOfReadingPrerecordedAudioOnly,
            ]
        )

        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.WaysOfReading(
                visualAdjustments: .unknown,
                nonvisualReading: .unreadable,
                nonvisualReadingAltText: false,
                prerecordedAudio: .audioComplementary
            ).statements.map(\.key),
            [
                .waysOfReadingVisualAdjustmentsUnknown,
                .waysOfReadingNonvisualReadingNone,
                .waysOfReadingPrerecordedAudioComplementary,
            ]
        )
    }

    func testNavigationTitle() {
        XCTAssertEqual(AccessibilityMetadataDisplayGuide.Navigation().localizedTitle, "Navigation")
    }

    func testNavigationShouldDisplay() {
        // Navigation should be displayed only if noMetadata is false
        let navigationWithMetadata = AccessibilityMetadataDisplayGuide.Navigation(
            noMetadata: false,
            tableOfContents: true,
            index: false,
            headings: false,
            page: false
        )
        XCTAssertTrue(navigationWithMetadata.shouldDisplay)

        let navigationWithoutMetadata = AccessibilityMetadataDisplayGuide.Navigation(
            noMetadata: true,
            tableOfContents: true,
            index: false,
            headings: false,
            page: false
        )
        XCTAssertFalse(navigationWithoutMetadata.shouldDisplay)
    }

    func testNavigationStatements() {
        // Test when noMetadata is true
        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.Navigation(
                noMetadata: true,
                tableOfContents: true,
                index: false,
                headings: true,
                page: false
            ).statements.map(\.key),
            [
                .navigationNoMetadata,
            ]
        )

        // Test when all features are enabled
        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.Navigation(
                noMetadata: false,
                tableOfContents: true,
                index: true,
                headings: true,
                page: true
            ).statements.map(\.key),
            [
                .navigationTOC,
                .navigationIndex,
                .navigationStructural,
                .navigationPageNavigation,
            ]
        )

        // Test individual features
        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.Navigation(
                noMetadata: false,
                tableOfContents: true,
                index: false,
                headings: false,
                page: false
            ).statements.map(\.key),
            [
                .navigationTOC,
            ]
        )

        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.Navigation(
                noMetadata: false,
                tableOfContents: false,
                index: true,
                headings: false,
                page: false
            ).statements.map(\.key),
            [
                .navigationIndex,
            ]
        )

        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.Navigation(
                noMetadata: false,
                tableOfContents: false,
                index: false,
                headings: true,
                page: false
            ).statements.map(\.key),
            [
                .navigationStructural,
            ]
        )

        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.Navigation(
                noMetadata: false,
                tableOfContents: false,
                index: false,
                headings: false,
                page: true
            ).statements.map(\.key),
            [
                .navigationPageNavigation,
            ]
        )
    }

    func testRichContentTitle() {
        XCTAssertEqual(AccessibilityMetadataDisplayGuide.RichContent().localizedTitle, "Rich content")
    }

    func testRichContentShouldDisplay() {
        // RichContent should be displayed only if noMetadata is false
        let richContentWithMetadata = AccessibilityMetadataDisplayGuide.RichContent(
            noMetadata: false,
            extendedAltTextDescriptions: true,
            mathFormula: false,
            mathFormulaAsMathML: false,
            mathFormulaAsLaTeX: false,
            chemicalFormulaAsMathML: false,
            chemicalFormulaAsLaTeX: false,
            closedCaptions: false,
            openCaptions: false,
            transcript: false
        )
        XCTAssertTrue(richContentWithMetadata.shouldDisplay)

        let richContentWithoutMetadata = AccessibilityMetadataDisplayGuide.RichContent(
            noMetadata: true,
            extendedAltTextDescriptions: true,
            mathFormula: false,
            mathFormulaAsMathML: false,
            mathFormulaAsLaTeX: false,
            chemicalFormulaAsMathML: false,
            chemicalFormulaAsLaTeX: false,
            closedCaptions: false,
            openCaptions: false,
            transcript: false
        )
        XCTAssertFalse(richContentWithoutMetadata.shouldDisplay)
    }

    func testRichContentStatements() {
        // Test when noMetadata is true
        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.RichContent(
                noMetadata: true,
                extendedAltTextDescriptions: true,
                mathFormula: false,
                mathFormulaAsMathML: true,
                mathFormulaAsLaTeX: false,
                chemicalFormulaAsMathML: false,
                chemicalFormulaAsLaTeX: false,
                closedCaptions: false,
                openCaptions: false,
                transcript: false
            ).statements.map(\.key),
            [
                .richContentUnknown,
            ]
        )

        // Test when all features are enabled
        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.RichContent(
                noMetadata: false,
                extendedAltTextDescriptions: true,
                mathFormula: true,
                mathFormulaAsMathML: true,
                mathFormulaAsLaTeX: true,
                chemicalFormulaAsMathML: true,
                chemicalFormulaAsLaTeX: true,
                closedCaptions: true,
                openCaptions: true,
                transcript: true
            ).statements.map(\.key),
            [
                .richContentExtended,
                .richContentAccessibleMathDescribed,
                .richContentAccessibleMathAsMathML,
                .richContentAccessibleMathAsLaTeX,
                .richContentAccessibleChemistryAsMathML,
                .richContentAccessibleChemistryAsLaTeX,
                .richContentClosedCaptions,
                .richContentOpenCaptions,
                .richContentTranscript,
            ]
        )

        // Test individual features
        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.RichContent(
                noMetadata: false,
                extendedAltTextDescriptions: true,
                mathFormula: false,
                mathFormulaAsMathML: false,
                mathFormulaAsLaTeX: false,
                chemicalFormulaAsMathML: false,
                chemicalFormulaAsLaTeX: false,
                closedCaptions: false,
                openCaptions: false,
                transcript: false
            ).statements.map(\.key),
            [
                .richContentExtended,
            ]
        )

        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.RichContent(
                noMetadata: false,
                extendedAltTextDescriptions: false,
                mathFormula: true,
                mathFormulaAsMathML: false,
                mathFormulaAsLaTeX: false,
                chemicalFormulaAsMathML: false,
                chemicalFormulaAsLaTeX: false,
                closedCaptions: false,
                openCaptions: false,
                transcript: false
            ).statements.map(\.key),
            [
                .richContentAccessibleMathDescribed,
            ]
        )

        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.RichContent(
                noMetadata: false,
                extendedAltTextDescriptions: false,
                mathFormula: false,
                mathFormulaAsMathML: true,
                mathFormulaAsLaTeX: false,
                chemicalFormulaAsMathML: false,
                chemicalFormulaAsLaTeX: false,
                closedCaptions: false,
                openCaptions: false,
                transcript: false
            ).statements.map(\.key),
            [
                .richContentAccessibleMathAsMathML,
            ]
        )

        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.RichContent(
                noMetadata: false,
                extendedAltTextDescriptions: false,
                mathFormula: false,
                mathFormulaAsMathML: false,
                mathFormulaAsLaTeX: true,
                chemicalFormulaAsMathML: false,
                chemicalFormulaAsLaTeX: false,
                closedCaptions: false,
                openCaptions: false,
                transcript: false
            ).statements.map(\.key),
            [
                .richContentAccessibleMathAsLaTeX,
            ]
        )

        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.RichContent(
                noMetadata: false,
                extendedAltTextDescriptions: false,
                mathFormula: false,
                mathFormulaAsMathML: false,
                mathFormulaAsLaTeX: false,
                chemicalFormulaAsMathML: true,
                chemicalFormulaAsLaTeX: false,
                closedCaptions: false,
                openCaptions: false,
                transcript: false
            ).statements.map(\.key),
            [
                .richContentAccessibleChemistryAsMathML,
            ]
        )

        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.RichContent(
                noMetadata: false,
                extendedAltTextDescriptions: false,
                mathFormula: false,
                mathFormulaAsMathML: false,
                mathFormulaAsLaTeX: false,
                chemicalFormulaAsMathML: false,
                chemicalFormulaAsLaTeX: true,
                closedCaptions: false,
                openCaptions: false,
                transcript: false
            ).statements.map(\.key),
            [
                .richContentAccessibleChemistryAsLaTeX,
            ]
        )

        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.RichContent(
                noMetadata: false,
                extendedAltTextDescriptions: false,
                mathFormula: false,
                mathFormulaAsMathML: false,
                mathFormulaAsLaTeX: false,
                chemicalFormulaAsMathML: false,
                chemicalFormulaAsLaTeX: false,
                closedCaptions: true,
                openCaptions: false,
                transcript: false
            ).statements.map(\.key),
            [
                .richContentClosedCaptions,
            ]
        )

        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.RichContent(
                noMetadata: false,
                extendedAltTextDescriptions: false,
                mathFormula: false,
                mathFormulaAsMathML: false,
                mathFormulaAsLaTeX: false,
                chemicalFormulaAsMathML: false,
                chemicalFormulaAsLaTeX: false,
                closedCaptions: false,
                openCaptions: true,
                transcript: false
            ).statements.map(\.key),
            [
                .richContentOpenCaptions,
            ]
        )

        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.RichContent(
                noMetadata: false,
                extendedAltTextDescriptions: false,
                mathFormula: false,
                mathFormulaAsMathML: false,
                mathFormulaAsLaTeX: false,
                chemicalFormulaAsMathML: false,
                chemicalFormulaAsLaTeX: false,
                closedCaptions: false,
                openCaptions: false,
                transcript: true
            ).statements.map(\.key),
            [
                .richContentTranscript,
            ]
        )
    }

    func testAdditionalInformationTitle() {
        XCTAssertEqual(AccessibilityMetadataDisplayGuide.AdditionalInformation().localizedTitle, "Additional accessibility information")
    }

    func testAdditionalInformationShouldDisplay() {
        // AdditionalInformation should be displayed only if noMetadata is false
        let additionalInfoWithMetadata = AccessibilityMetadataDisplayGuide.AdditionalInformation(
            noMetadata: false,
            pageBreakMarkers: true,
            aria: false,
            audioDescriptions: false,
            braille: false,
            someRubyAnnotations: false,
            fullRubyAnnotations: false,
            highAudioContrast: false,
            highColorContrast: false,
            largePrint: false,
            signLanguage: false,
            tactileGraphics: false,
            tactileObjects: false,
            textToSpeechHinting: false
        )
        XCTAssertTrue(additionalInfoWithMetadata.shouldDisplay)

        let additionalInfoWithoutMetadata = AccessibilityMetadataDisplayGuide.AdditionalInformation(
            noMetadata: true,
            pageBreakMarkers: true,
            aria: false,
            audioDescriptions: false,
            braille: false,
            someRubyAnnotations: false,
            fullRubyAnnotations: false,
            highAudioContrast: false,
            highColorContrast: false,
            largePrint: false,
            signLanguage: false,
            tactileGraphics: false,
            tactileObjects: false,
            textToSpeechHinting: false
        )
        XCTAssertFalse(additionalInfoWithoutMetadata.shouldDisplay)
    }

    func testAdditionalInformationStatements() {
        // Test when noMetadata is true
        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.AdditionalInformation(
                noMetadata: true,
                pageBreakMarkers: false,
                aria: false,
                audioDescriptions: false,
                braille: false,
                someRubyAnnotations: false,
                fullRubyAnnotations: false,
                highAudioContrast: false,
                highColorContrast: false,
                largePrint: false,
                signLanguage: false,
                tactileGraphics: false,
                tactileObjects: false,
                textToSpeechHinting: false
            ).statements.map(\.key),
            []
        )

        // Test when all features are enabled
        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.AdditionalInformation(
                noMetadata: false,
                pageBreakMarkers: true,
                aria: true,
                audioDescriptions: true,
                braille: true,
                someRubyAnnotations: true,
                fullRubyAnnotations: true,
                highAudioContrast: true,
                highColorContrast: true,
                largePrint: true,
                signLanguage: true,
                tactileGraphics: true,
                tactileObjects: true,
                textToSpeechHinting: true
            ).statements.map(\.key),
            [
                .additionalAccessibilityInformationPageBreaks,
                .additionalAccessibilityInformationARIA,
                .additionalAccessibilityInformationAudioDescriptions,
                .additionalAccessibilityInformationBraille,
                .additionalAccessibilityInformationRubyAnnotations,
                .additionalAccessibilityInformationFullRubyAnnotations,
                .additionalAccessibilityInformationHighContrastBetweenForegroundAndBackgroundAudio,
                .additionalAccessibilityInformationHighContrastBetweenTextAndBackground,
                .additionalAccessibilityInformationLargePrint,
                .additionalAccessibilityInformationSignLanguage,
                .additionalAccessibilityInformationTactileGraphics,
                .additionalAccessibilityInformationTactileObjects,
                .additionalAccessibilityInformationTextToSpeechHinting,
            ]
        )

        // Test individual features
        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.AdditionalInformation(
                noMetadata: false,
                pageBreakMarkers: true,
                aria: false,
                audioDescriptions: false,
                braille: false,
                someRubyAnnotations: false,
                fullRubyAnnotations: false,
                highAudioContrast: false,
                highColorContrast: false,
                largePrint: false,
                signLanguage: false,
                tactileGraphics: false,
                tactileObjects: false,
                textToSpeechHinting: false
            ).statements.map(\.key),
            [
                .additionalAccessibilityInformationPageBreaks,
            ]
        )

        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.AdditionalInformation(
                noMetadata: false,
                pageBreakMarkers: false,
                aria: true,
                audioDescriptions: false,
                braille: false,
                someRubyAnnotations: false,
                fullRubyAnnotations: false,
                highAudioContrast: false,
                highColorContrast: false,
                largePrint: false,
                signLanguage: false,
                tactileGraphics: false,
                tactileObjects: false,
                textToSpeechHinting: false
            ).statements.map(\.key),
            [
                .additionalAccessibilityInformationARIA,
            ]
        )

        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.AdditionalInformation(
                noMetadata: false,
                pageBreakMarkers: false,
                aria: false,
                audioDescriptions: true,
                braille: false,
                someRubyAnnotations: false,
                fullRubyAnnotations: false,
                highAudioContrast: false,
                highColorContrast: false,
                largePrint: false,
                signLanguage: false,
                tactileGraphics: false,
                tactileObjects: false,
                textToSpeechHinting: false
            ).statements.map(\.key),
            [
                .additionalAccessibilityInformationAudioDescriptions,
            ]
        )

        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.AdditionalInformation(
                noMetadata: false,
                pageBreakMarkers: false,
                aria: false,
                audioDescriptions: false,
                braille: true,
                someRubyAnnotations: false,
                fullRubyAnnotations: false,
                highAudioContrast: false,
                highColorContrast: false,
                largePrint: false,
                signLanguage: false,
                tactileGraphics: false,
                tactileObjects: false,
                textToSpeechHinting: false
            ).statements.map(\.key),
            [
                .additionalAccessibilityInformationBraille,
            ]
        )

        // Additional tests for each feature
        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.AdditionalInformation(
                noMetadata: false,
                pageBreakMarkers: false,
                aria: false,
                audioDescriptions: false,
                braille: false,
                someRubyAnnotations: true,
                fullRubyAnnotations: false,
                highAudioContrast: false,
                highColorContrast: false,
                largePrint: false,
                signLanguage: false,
                tactileGraphics: false,
                tactileObjects: false,
                textToSpeechHinting: false
            ).statements.map(\.key),
            [
                .additionalAccessibilityInformationRubyAnnotations,
            ]
        )

        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.AdditionalInformation(
                noMetadata: false,
                pageBreakMarkers: false,
                aria: false,
                audioDescriptions: false,
                braille: false,
                someRubyAnnotations: false,
                fullRubyAnnotations: true,
                highAudioContrast: false,
                highColorContrast: false,
                largePrint: false,
                signLanguage: false,
                tactileGraphics: false,
                tactileObjects: false,
                textToSpeechHinting: false
            ).statements.map(\.key),
            [
                .additionalAccessibilityInformationFullRubyAnnotations,
            ]
        )

        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.AdditionalInformation(
                noMetadata: false,
                pageBreakMarkers: false,
                aria: false,
                audioDescriptions: false,
                braille: false,
                someRubyAnnotations: false,
                fullRubyAnnotations: false,
                highAudioContrast: true,
                highColorContrast: false,
                largePrint: false,
                signLanguage: false,
                tactileGraphics: false,
                tactileObjects: false,
                textToSpeechHinting: false
            ).statements.map(\.key),
            [
                .additionalAccessibilityInformationHighContrastBetweenForegroundAndBackgroundAudio,
            ]
        )

        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.AdditionalInformation(
                noMetadata: false,
                pageBreakMarkers: false,
                aria: false,
                audioDescriptions: false,
                braille: false,
                someRubyAnnotations: false,
                fullRubyAnnotations: false,
                highAudioContrast: false,
                highColorContrast: true,
                largePrint: false,
                signLanguage: false,
                tactileGraphics: false,
                tactileObjects: false,
                textToSpeechHinting: false
            ).statements.map(\.key),
            [
                .additionalAccessibilityInformationHighContrastBetweenTextAndBackground,
            ]
        )

        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.AdditionalInformation(
                noMetadata: false,
                pageBreakMarkers: false,
                aria: false,
                audioDescriptions: false,
                braille: false,
                someRubyAnnotations: false,
                fullRubyAnnotations: false,
                highAudioContrast: false,
                highColorContrast: false,
                largePrint: true,
                signLanguage: false,
                tactileGraphics: false,
                tactileObjects: false,
                textToSpeechHinting: false
            ).statements.map(\.key),
            [
                .additionalAccessibilityInformationLargePrint,
            ]
        )

        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.AdditionalInformation(
                noMetadata: false,
                pageBreakMarkers: false,
                aria: false,
                audioDescriptions: false,
                braille: false,
                someRubyAnnotations: false,
                fullRubyAnnotations: false,
                highAudioContrast: false,
                highColorContrast: false,
                largePrint: false,
                signLanguage: true,
                tactileGraphics: false,
                tactileObjects: false,
                textToSpeechHinting: false
            ).statements.map(\.key),
            [
                .additionalAccessibilityInformationSignLanguage,
            ]
        )

        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.AdditionalInformation(
                noMetadata: false,
                pageBreakMarkers: false,
                aria: false,
                audioDescriptions: false,
                braille: false,
                someRubyAnnotations: false,
                fullRubyAnnotations: false,
                highAudioContrast: false,
                highColorContrast: false,
                largePrint: false,
                signLanguage: false,
                tactileGraphics: true,
                tactileObjects: false,
                textToSpeechHinting: false
            ).statements.map(\.key),
            [
                .additionalAccessibilityInformationTactileGraphics,
            ]
        )

        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.AdditionalInformation(
                noMetadata: false,
                pageBreakMarkers: false,
                aria: false,
                audioDescriptions: false,
                braille: false,
                someRubyAnnotations: false,
                fullRubyAnnotations: false,
                highAudioContrast: false,
                highColorContrast: false,
                largePrint: false,
                signLanguage: false,
                tactileGraphics: false,
                tactileObjects: true,
                textToSpeechHinting: false
            ).statements.map(\.key),
            [
                .additionalAccessibilityInformationTactileObjects,
            ]
        )

        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.AdditionalInformation(
                noMetadata: false,
                pageBreakMarkers: false,
                aria: false,
                audioDescriptions: false,
                braille: false,
                someRubyAnnotations: false,
                fullRubyAnnotations: false,
                highAudioContrast: false,
                highColorContrast: false,
                largePrint: false,
                signLanguage: false,
                tactileGraphics: false,
                tactileObjects: false,
                textToSpeechHinting: true
            ).statements.map(\.key),
            [
                .additionalAccessibilityInformationTextToSpeechHinting,
            ]
        )
    }

    func testHazardsTitle() {
        XCTAssertEqual(AccessibilityMetadataDisplayGuide.Hazards().localizedTitle, "Hazards")
    }

    func testHazardsShouldDisplay() {
        // Hazards should be hidden only if no metadata is provided
        let hazardsWithMetadata = AccessibilityMetadataDisplayGuide.Hazards(
            flashing: .yes,
            motion: .noMetadata,
            sounds: .noMetadata
        )
        XCTAssertTrue(hazardsWithMetadata.shouldDisplay)

        let hazardsWithoutMetadata = AccessibilityMetadataDisplayGuide.Hazards(
            flashing: .noMetadata,
            motion: .noMetadata,
            sounds: .noMetadata
        )
        XCTAssertFalse(hazardsWithoutMetadata.shouldDisplay)
    }

    func testHazardsStatements() {
        // Test when noMetadata is true
        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.Hazards(
                flashing: .noMetadata,
                motion: .noMetadata,
                sounds: .noMetadata
            ).statements.map(\.key),
            [
                .hazardsNoMetadata,
            ]
        )

        // Test when no hazards are present
        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.Hazards(
                flashing: .no,
                motion: .no,
                sounds: .no
            ).statements.map(\.key),
            [
                .hazardsNone,
            ]
        )

        // Test when hazards are unknown
        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.Hazards(
                flashing: .unknown,
                motion: .unknown,
                sounds: .unknown
            ).statements.map(\.key),
            [
                .hazardsUnknown,
            ]
        )

        // Test individual hazards
        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.Hazards(
                flashing: .yes,
                motion: .no,
                sounds: .no
            ).statements.map(\.key),
            [
                .hazardsFlashing,
                .hazardsMotionNone,
                .hazardsSoundNone,
            ]
        )

        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.Hazards(
                flashing: .no,
                motion: .yes,
                sounds: .no
            ).statements.map(\.key),
            [
                .hazardsMotion,
                .hazardsFlashingNone,
                .hazardsSoundNone,
            ]
        )

        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.Hazards(
                flashing: .no,
                motion: .no,
                sounds: .yes
            ).statements.map(\.key),
            [
                .hazardsSound,
                .hazardsFlashingNone,
                .hazardsMotionNone,
            ]
        )

        // Test combinations of hazards
        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.Hazards(
                flashing: .yes,
                motion: .yes,
                sounds: .yes
            ).statements.map(\.key),
            [
                .hazardsFlashing,
                .hazardsMotion,
                .hazardsSound,
            ]
        )

        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.Hazards(
                flashing: .unknown,
                motion: .yes,
                sounds: .no
            ).statements.map(\.key),
            [
                .hazardsMotion,
                .hazardsFlashingUnknown,
                .hazardsSoundNone,
            ]
        )

        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.Hazards(
                flashing: .yes,
                motion: .unknown,
                sounds: .unknown
            ).statements.map(\.key),
            [
                .hazardsFlashing,
                .hazardsMotionUnknown,
                .hazardsSoundUnknown,
            ]
        )
    }

    func testConformanceTitle() {
        XCTAssertEqual(AccessibilityMetadataDisplayGuide.Conformance().localizedTitle, "Conformance")
    }

    func testConformanceShouldDisplay() {
        // Conformance should always be displayed
        XCTAssertTrue(AccessibilityMetadataDisplayGuide.Conformance(profile: nil).shouldDisplay)
        XCTAssertTrue(AccessibilityMetadataDisplayGuide.Conformance(profile: .epubA11y10WCAG20A).shouldDisplay)
    }

    func testConformanceStatements() {
        func test(_ profile: Accessibility.Profile?, expected: AccessibilityDisplayStatement.Key) {
            XCTAssertEqual(
                AccessibilityMetadataDisplayGuide.Conformance(profile: profile).statements.map(\.key),
                [expected]
            )
        }

        // Test no profile
        test(nil, expected: .conformanceNo)
        // Test unknown profile
        test(.init("https://custom-profile"), expected: .conformanceUnknownStandard)
        // Test level A profiles
        test(.epubA11y10WCAG20A, expected: .conformanceA)
        test(.epubA11y11WCAG20A, expected: .conformanceA)
        test(.epubA11y11WCAG21A, expected: .conformanceA)
        test(.epubA11y11WCAG22A, expected: .conformanceA)
        // Test level AA profiles
        test(.epubA11y10WCAG20AA, expected: .conformanceAA)
        test(.epubA11y11WCAG20AA, expected: .conformanceAA)
        test(.epubA11y11WCAG21AA, expected: .conformanceAA)
        test(.epubA11y11WCAG22AA, expected: .conformanceAA)
        // Test level AAA profiles
        test(.epubA11y10WCAG20AAA, expected: .conformanceAAA)
        test(.epubA11y11WCAG20AAA, expected: .conformanceAAA)
        test(.epubA11y11WCAG21AAA, expected: .conformanceAAA)
        test(.epubA11y11WCAG22AAA, expected: .conformanceAAA)
    }

    func testLegalTitle() {
        XCTAssertEqual(AccessibilityMetadataDisplayGuide.Legal().localizedTitle, "Legal considerations")
    }

    func testLegalShouldDisplay() {
        // Legal should be displayed only if noMetadata is false
        let legalWithMetadata = AccessibilityMetadataDisplayGuide.Legal(
            noMetadata: false,
            exemption: true
        )
        XCTAssertTrue(legalWithMetadata.shouldDisplay)

        let legalWithoutMetadata = AccessibilityMetadataDisplayGuide.Legal(
            noMetadata: true,
            exemption: true
        )
        XCTAssertFalse(legalWithoutMetadata.shouldDisplay)
    }

    func testLegalStatements() {
        // Test when noMetadata is true
        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.Legal(
                noMetadata: true,
                exemption: false
            ).statements.map(\.key),
            [
                .legalConsiderationsNoMetadata,
            ]
        )

        // Test when exemption is claimed
        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.Legal(
                noMetadata: false,
                exemption: true
            ).statements.map(\.key),
            [
                .legalConsiderationsExempt,
            ]
        )

        // Test when noMetadata is false and exemption is false
        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.Legal(
                noMetadata: false,
                exemption: false
            ).statements.map(\.key),
            [
                .legalConsiderationsNoMetadata,
            ]
        )
    }

    func testAccessibilitySummaryTitle() {
        XCTAssertEqual(AccessibilityMetadataDisplayGuide.AccessibilitySummary().localizedTitle, "Accessibility summary")
    }

    func testAccessibilitySummaryShouldDisplay() {
        // AccessibilitySummary should be displayed only if summary is not nil
        let summaryWithContent = AccessibilityMetadataDisplayGuide.AccessibilitySummary(summary: "This is a summary.")
        XCTAssertTrue(summaryWithContent.shouldDisplay)

        let summaryWithoutContent = AccessibilityMetadataDisplayGuide.AccessibilitySummary(summary: nil)
        XCTAssertFalse(summaryWithoutContent.shouldDisplay)
    }

    func testAccessibilitySummaryStatements() {
        // Test when summary is nil
        XCTAssertEqual(
            AccessibilityMetadataDisplayGuide.AccessibilitySummary(summary: nil).statements.map(\.key),
            [
                .accessibilitySummaryNoMetadata,
            ]
        )

        // Test when summary is provided
        let summaryText = "This publication is accessible and includes features such as text-to-speech and high contrast."
        let fields = AccessibilityMetadataDisplayGuide.AccessibilitySummary(summary: summaryText).statements
        XCTAssertEqual(fields.count, 1)
        let field = fields[0]
        XCTAssertEqual(field.key, .accessibilitySummary)
        XCTAssertEqual(field.localizedString(descriptive: false).string, summaryText)
        XCTAssertEqual(field.localizedString(descriptive: true).string, summaryText)
    }
}
