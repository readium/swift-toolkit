//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

typealias AccessibilitySummary = AccessibilityMetadataDisplayGuide.AccessibilitySummary
typealias AdditionalInformation = AccessibilityMetadataDisplayGuide.AdditionalInformation
typealias Conformance = AccessibilityMetadataDisplayGuide.Conformance
typealias Hazards = AccessibilityMetadataDisplayGuide.Hazards
typealias Legal = AccessibilityMetadataDisplayGuide.Legal
typealias Navigation = AccessibilityMetadataDisplayGuide.Navigation
typealias RichContent = AccessibilityMetadataDisplayGuide.RichContent
typealias WaysOfReading = AccessibilityMetadataDisplayGuide.WaysOfReading

class AccessibilityMetadataDisplayGuideTests: XCTestCase {
    func testDisplayStatementLocalizedString() {
        let statement = AccessibilityDisplayStatement(string: .waysOfReadingNonvisualReadingReadable)

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
            string: .waysOfReadingNonvisualReadingReadable,
            compactLocalizedString: "Compact",
            descriptiveLocalizedString: "Descriptive"
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

    func testWaysOfReadingInitVisualAdjustments() {
        func test(layout: Layout, a11y: Accessibility?, expected: WaysOfReading.VisualAdjustments) {
            let sut = WaysOfReading(publication: publication(
                layout: layout,
                accessibility: a11y
            ))
            XCTAssertEqual(sut.visualAdjustments, expected)
        }

        let displayTransformability = Accessibility(features: [.displayTransformability])

        test(layout: .reflowable, a11y: nil, expected: .unknown)
        test(layout: .reflowable, a11y: displayTransformability, expected: .modifiable)
        test(layout: .fixed, a11y: nil, expected: .unmodifiable)
        test(layout: .fixed, a11y: displayTransformability, expected: .modifiable)
    }

    func testWaysOfReadingInitNonvisualReading() {
        func test(_ a11y: Accessibility?, expected: WaysOfReading.NonvisualReading) {
            let sut = WaysOfReading(publication: publication(accessibility: a11y))
            XCTAssertEqual(sut.nonvisualReading, expected)
        }

        // No metadata
        test(nil, expected: .noMetadata)
        test(.init(accessModes: [], accessModesSufficient: []), expected: .noMetadata)

        // It's readable when there's only textual content or an access mode
        // sufficient of textual.
        test(.init(accessModes: [.textual]), expected: .readable)
        test(.init(accessModes: [.auditory], accessModesSufficient: [[.textual]]), expected: .readable)

        // It's partially readable:
        // ... when it contains textual content and other medium.
        test(.init(accessModes: [.textual, .auditory]), expected: .notFully)
        test(.init(accessModesSufficient: [[.textual, .auditory]]), expected: .notFully)
        // ... when it contains textual alternatives features.
        test(.init(accessModes: [.visual], features: [.longDescription]), expected: .notFully)
        test(.init(accessModes: [.visual], features: [.alternativeText]), expected: .notFully)
        test(.init(accessModes: [.visual], features: [.describedMath]), expected: .notFully)
        test(.init(accessModes: [.visual], features: [.transcript]), expected: .notFully)

        // It's not readable:
        // ... when it contains only audio content.
        test(.init(accessModes: [.auditory]), expected: .unreadable)
        // ... when it contains only visual content.
        test(.init(accessModes: [.visual]), expected: .unreadable)
        // ... when it contains a mix of non textual content.
        test(.init(accessModes: [.visual, .auditory, .mathOnVisual]), expected: .unreadable)
    }

    func testWaysOfReadingInitNonvisualReadingAltText() {
        func test(_ a11y: Accessibility?, expected: Bool) {
            let sut = WaysOfReading(publication: publication(accessibility: a11y))
            XCTAssertEqual(sut.nonvisualReadingAltText, expected)
        }

        // No metadata
        test(nil, expected: false)

        // No textual alternative features
        test(.init(), expected: false)
        test(.init(features: [.annotations]), expected: false)

        // With textual alternative features
        test(.init(features: [.longDescription]), expected: true)
        test(.init(features: [.alternativeText]), expected: true)
        test(.init(features: [.describedMath]), expected: true)
        test(.init(features: [.transcript]), expected: true)
    }

    func testWaysOfReadingInitPrerecordedAudio() {
        func test(_ a11y: Accessibility?, expected: WaysOfReading.PrerecordedAudio) {
            let sut = WaysOfReading(publication: publication(accessibility: a11y))
            XCTAssertEqual(sut.prerecordedAudio, expected)
        }

        // No metadata
        test(nil, expected: .noMetadata)
        test(.init(accessModes: [], accessModesSufficient: []), expected: .noMetadata)

        // No audio detected
        test(.init(accessModes: [.textual], accessModesSufficient: [[.textual]]), expected: .noMetadata)

        // Audio is sufficient
        test(.init(accessModes: [.textual], accessModesSufficient: [[.auditory], [.textual]]), expected: .audioOnly)
        test(.init(accessModes: [.textual, .auditory], accessModesSufficient: [[.auditory], [.textual]]), expected: .audioOnly)

        // Some audio content
        test(.init(accessModes: [.textual, .auditory]), expected: .audioComplementary)
        test(.init(accessModes: [.auditory], accessModesSufficient: [[.textual]]), expected: .audioComplementary)

        // Synchronized audio detected
        test(.init(accessModes: [.textual], accessModesSufficient: [[.textual]], features: [.synchronizedAudioText]), expected: .synchronized)
    }

    func testWaysOfReadingTitle() {
        XCTAssertEqual(WaysOfReading().localizedTitle, "Ways of reading")
    }

    func testWaysOfReadingShouldDisplay() {
        // WaysOfReading should always be displayed
        XCTAssertTrue(WaysOfReading(
            visualAdjustments: .unknown,
            nonvisualReading: .noMetadata,
            nonvisualReadingAltText: false,
            prerecordedAudio: .noMetadata
        ).shouldDisplay)
    }

    func testWaysOfReadingStatements() {
        XCTAssertEqual(
            WaysOfReading(
                visualAdjustments: .unknown,
                nonvisualReading: .noMetadata,
                nonvisualReadingAltText: true,
                prerecordedAudio: .noMetadata
            ).statements.map(\.id),
            [
                .waysOfReadingVisualAdjustmentsUnknown,
                .waysOfReadingNonvisualReadingNoMetadata,
                .waysOfReadingNonvisualReadingAltText,
                .waysOfReadingPrerecordedAudioNoMetadata,
            ]
        )

        XCTAssertEqual(
            WaysOfReading(
                visualAdjustments: .modifiable,
                nonvisualReading: .readable,
                nonvisualReadingAltText: false,
                prerecordedAudio: .synchronized
            ).statements.map(\.id),
            [
                .waysOfReadingVisualAdjustmentsModifiable,
                .waysOfReadingNonvisualReadingReadable,
                .waysOfReadingPrerecordedAudioSynchronized,
            ]
        )

        XCTAssertEqual(
            WaysOfReading(
                visualAdjustments: .unmodifiable,
                nonvisualReading: .notFully,
                nonvisualReadingAltText: false,
                prerecordedAudio: .audioOnly
            ).statements.map(\.id),
            [
                .waysOfReadingVisualAdjustmentsUnmodifiable,
                .waysOfReadingNonvisualReadingNotFully,
                .waysOfReadingPrerecordedAudioOnly,
            ]
        )

        XCTAssertEqual(
            WaysOfReading(
                visualAdjustments: .unknown,
                nonvisualReading: .unreadable,
                nonvisualReadingAltText: false,
                prerecordedAudio: .audioComplementary
            ).statements.map(\.id),
            [
                .waysOfReadingVisualAdjustmentsUnknown,
                .waysOfReadingNonvisualReadingNone,
                .waysOfReadingPrerecordedAudioComplementary,
            ]
        )
    }

    func testNavigationInit() {
        func test(a11y: Accessibility?, expected: Navigation) {
            let sut = Navigation(publication: publication(accessibility: a11y))
            XCTAssertEqual(sut, expected)
        }

        // No navigation metadata
        test(a11y: nil, expected: Navigation(tableOfContents: false, index: false, headings: false, page: false))
        test(a11y: .init(), expected: Navigation(tableOfContents: false, index: false, headings: false, page: false))

        // Individual features
        test(a11y: .init(features: [.tableOfContents]), expected: Navigation(tableOfContents: true, index: false, headings: false, page: false))
        test(a11y: .init(features: [.index]), expected: Navigation(tableOfContents: false, index: true, headings: false, page: false))
        test(a11y: .init(features: [.structuralNavigation]), expected: Navigation(tableOfContents: false, index: false, headings: true, page: false))
        test(a11y: .init(features: [.pageNavigation]), expected: Navigation(tableOfContents: false, index: false, headings: false, page: true))

        // All features
        test(a11y: .init(features: [.index, .structuralNavigation, .pageNavigation, .tableOfContents]), expected: Navigation(tableOfContents: true, index: true, headings: true, page: true))
    }

    func testNavigationTitle() {
        XCTAssertEqual(Navigation().localizedTitle, "Navigation")
    }

    func testNavigationShouldDisplay() {
        // Navigation should be displayed only if there are metadata.
        let navigationWithMetadata = Navigation(
            tableOfContents: false,
            index: false,
            headings: false,
            page: false
        )
        XCTAssertFalse(navigationWithMetadata.shouldDisplay)

        let navigationWithoutMetadata = Navigation(
            tableOfContents: true,
            index: false,
            headings: false,
            page: false
        )
        XCTAssertTrue(navigationWithoutMetadata.shouldDisplay)
    }

    func testNavigationStatements() {
        // Test when no features are enabled.
        XCTAssertEqual(
            Navigation(
                tableOfContents: false,
                index: false,
                headings: false,
                page: false
            ).statements.map(\.id),
            [
                .navigationNoMetadata,
            ]
        )

        // Test when all features are enabled
        XCTAssertEqual(
            Navigation(
                tableOfContents: true,
                index: true,
                headings: true,
                page: true
            ).statements.map(\.id),
            [
                .navigationToc,
                .navigationIndex,
                .navigationStructural,
                .navigationPageNavigation,
            ]
        )

        // Test individual features
        XCTAssertEqual(
            Navigation(
                tableOfContents: true,
                index: false,
                headings: false,
                page: false
            ).statements.map(\.id),
            [
                .navigationToc,
            ]
        )

        XCTAssertEqual(
            Navigation(
                tableOfContents: false,
                index: true,
                headings: false,
                page: false
            ).statements.map(\.id),
            [
                .navigationIndex,
            ]
        )

        XCTAssertEqual(
            Navigation(
                tableOfContents: false,
                index: false,
                headings: true,
                page: false
            ).statements.map(\.id),
            [
                .navigationStructural,
            ]
        )

        XCTAssertEqual(
            Navigation(
                tableOfContents: false,
                index: false,
                headings: false,
                page: true
            ).statements.map(\.id),
            [
                .navigationPageNavigation,
            ]
        )
    }

    func testRichContentInit() {
        func test(a11y: Accessibility?, expected: RichContent) {
            let sut = RichContent(publication: publication(accessibility: a11y))
            XCTAssertEqual(sut, expected)
        }

        // No rich content metadata
        test(a11y: nil, expected: RichContent(extendedAltTextDescriptions: false, mathFormula: false, mathFormulaAsMathML: false, mathFormulaAsLaTeX: false, chemicalFormulaAsMathML: false, chemicalFormulaAsLaTeX: false, closedCaptions: false, openCaptions: false, transcript: false))
        test(a11y: .init(), expected: RichContent(extendedAltTextDescriptions: false, mathFormula: false, mathFormulaAsMathML: false, mathFormulaAsLaTeX: false, chemicalFormulaAsMathML: false, chemicalFormulaAsLaTeX: false, closedCaptions: false, openCaptions: false, transcript: false))

        // Individual features
        test(a11y: .init(features: [.longDescription]), expected: RichContent(extendedAltTextDescriptions: true, mathFormula: false, mathFormulaAsMathML: false, mathFormulaAsLaTeX: false, chemicalFormulaAsMathML: false, chemicalFormulaAsLaTeX: false, closedCaptions: false, openCaptions: false, transcript: false))
        test(a11y: .init(features: [.describedMath]), expected: RichContent(extendedAltTextDescriptions: false, mathFormula: true, mathFormulaAsMathML: false, mathFormulaAsLaTeX: false, chemicalFormulaAsMathML: false, chemicalFormulaAsLaTeX: false, closedCaptions: false, openCaptions: false, transcript: false))
        test(a11y: .init(features: [.mathML]), expected: RichContent(extendedAltTextDescriptions: false, mathFormula: false, mathFormulaAsMathML: true, mathFormulaAsLaTeX: false, chemicalFormulaAsMathML: false, chemicalFormulaAsLaTeX: false, closedCaptions: false, openCaptions: false, transcript: false))
        test(a11y: .init(features: [.latex]), expected: RichContent(extendedAltTextDescriptions: false, mathFormula: false, mathFormulaAsMathML: false, mathFormulaAsLaTeX: true, chemicalFormulaAsMathML: false, chemicalFormulaAsLaTeX: false, closedCaptions: false, openCaptions: false, transcript: false))
        test(a11y: .init(features: [.mathMLChemistry]), expected: RichContent(extendedAltTextDescriptions: false, mathFormula: false, mathFormulaAsMathML: false, mathFormulaAsLaTeX: false, chemicalFormulaAsMathML: true, chemicalFormulaAsLaTeX: false, closedCaptions: false, openCaptions: false, transcript: false))
        test(a11y: .init(features: [.latexChemistry]), expected: RichContent(extendedAltTextDescriptions: false, mathFormula: false, mathFormulaAsMathML: false, mathFormulaAsLaTeX: false, chemicalFormulaAsMathML: false, chemicalFormulaAsLaTeX: true, closedCaptions: false, openCaptions: false, transcript: false))
        test(a11y: .init(features: [.closedCaptions]), expected: RichContent(extendedAltTextDescriptions: false, mathFormula: false, mathFormulaAsMathML: false, mathFormulaAsLaTeX: false, chemicalFormulaAsMathML: false, chemicalFormulaAsLaTeX: false, closedCaptions: true, openCaptions: false, transcript: false))
        test(a11y: .init(features: [.openCaptions]), expected: RichContent(extendedAltTextDescriptions: false, mathFormula: false, mathFormulaAsMathML: false, mathFormulaAsLaTeX: false, chemicalFormulaAsMathML: false, chemicalFormulaAsLaTeX: false, closedCaptions: false, openCaptions: true, transcript: false))
        test(a11y: .init(features: [.transcript]), expected: RichContent(extendedAltTextDescriptions: false, mathFormula: false, mathFormulaAsMathML: false, mathFormulaAsLaTeX: false, chemicalFormulaAsMathML: false, chemicalFormulaAsLaTeX: false, closedCaptions: false, openCaptions: false, transcript: true))

        // All features
        test(a11y: .init(features: [
            .longDescription, .describedMath, .mathML, .latex, .mathMLChemistry,
            .latexChemistry, .closedCaptions, .openCaptions, .transcript,
        ]), expected: RichContent(extendedAltTextDescriptions: true, mathFormula: true, mathFormulaAsMathML: true, mathFormulaAsLaTeX: true, chemicalFormulaAsMathML: true, chemicalFormulaAsLaTeX: true, closedCaptions: true, openCaptions: true, transcript: true))
    }

    func testRichContentTitle() {
        XCTAssertEqual(RichContent().localizedTitle, "Rich content")
    }

    func testRichContentShouldDisplay() {
        // RichContent should be displayed only if there are some metadata.
        let richContentWithMetadata = RichContent(
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

        let richContentWithoutMetadata = RichContent(
            extendedAltTextDescriptions: false,
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
        // Test when there are no rich content.
        XCTAssertEqual(
            RichContent(
                extendedAltTextDescriptions: false,
                mathFormula: false,
                mathFormulaAsMathML: false,
                mathFormulaAsLaTeX: false,
                chemicalFormulaAsMathML: false,
                chemicalFormulaAsLaTeX: false,
                closedCaptions: false,
                openCaptions: false,
                transcript: false
            ).statements.map(\.id),
            [
                .richContentUnknown,
            ]
        )

        // Test when all features are enabled
        XCTAssertEqual(
            RichContent(
                extendedAltTextDescriptions: true,
                mathFormula: true,
                mathFormulaAsMathML: true,
                mathFormulaAsLaTeX: true,
                chemicalFormulaAsMathML: true,
                chemicalFormulaAsLaTeX: true,
                closedCaptions: true,
                openCaptions: true,
                transcript: true
            ).statements.map(\.id),
            [
                .richContentExtended,
                .richContentAccessibleMathDescribed,
                .richContentAccessibleMathAsMathml,
                .richContentAccessibleMathAsLatex,
                .richContentAccessibleChemistryAsMathml,
                .richContentAccessibleChemistryAsLatex,
                .richContentClosedCaptions,
                .richContentOpenCaptions,
                .richContentTranscript,
            ]
        )

        // Test individual features
        XCTAssertEqual(
            RichContent(
                extendedAltTextDescriptions: true,
                mathFormula: false,
                mathFormulaAsMathML: false,
                mathFormulaAsLaTeX: false,
                chemicalFormulaAsMathML: false,
                chemicalFormulaAsLaTeX: false,
                closedCaptions: false,
                openCaptions: false,
                transcript: false
            ).statements.map(\.id),
            [
                .richContentExtended,
            ]
        )

        XCTAssertEqual(
            RichContent(
                extendedAltTextDescriptions: false,
                mathFormula: true,
                mathFormulaAsMathML: false,
                mathFormulaAsLaTeX: false,
                chemicalFormulaAsMathML: false,
                chemicalFormulaAsLaTeX: false,
                closedCaptions: false,
                openCaptions: false,
                transcript: false
            ).statements.map(\.id),
            [
                .richContentAccessibleMathDescribed,
            ]
        )

        XCTAssertEqual(
            RichContent(
                extendedAltTextDescriptions: false,
                mathFormula: false,
                mathFormulaAsMathML: true,
                mathFormulaAsLaTeX: false,
                chemicalFormulaAsMathML: false,
                chemicalFormulaAsLaTeX: false,
                closedCaptions: false,
                openCaptions: false,
                transcript: false
            ).statements.map(\.id),
            [
                .richContentAccessibleMathAsMathml,
            ]
        )

        XCTAssertEqual(
            RichContent(
                extendedAltTextDescriptions: false,
                mathFormula: false,
                mathFormulaAsMathML: false,
                mathFormulaAsLaTeX: true,
                chemicalFormulaAsMathML: false,
                chemicalFormulaAsLaTeX: false,
                closedCaptions: false,
                openCaptions: false,
                transcript: false
            ).statements.map(\.id),
            [
                .richContentAccessibleMathAsLatex,
            ]
        )

        XCTAssertEqual(
            RichContent(
                extendedAltTextDescriptions: false,
                mathFormula: false,
                mathFormulaAsMathML: false,
                mathFormulaAsLaTeX: false,
                chemicalFormulaAsMathML: true,
                chemicalFormulaAsLaTeX: false,
                closedCaptions: false,
                openCaptions: false,
                transcript: false
            ).statements.map(\.id),
            [
                .richContentAccessibleChemistryAsMathml,
            ]
        )

        XCTAssertEqual(
            RichContent(
                extendedAltTextDescriptions: false,
                mathFormula: false,
                mathFormulaAsMathML: false,
                mathFormulaAsLaTeX: false,
                chemicalFormulaAsMathML: false,
                chemicalFormulaAsLaTeX: true,
                closedCaptions: false,
                openCaptions: false,
                transcript: false
            ).statements.map(\.id),
            [
                .richContentAccessibleChemistryAsLatex,
            ]
        )

        XCTAssertEqual(
            RichContent(
                extendedAltTextDescriptions: false,
                mathFormula: false,
                mathFormulaAsMathML: false,
                mathFormulaAsLaTeX: false,
                chemicalFormulaAsMathML: false,
                chemicalFormulaAsLaTeX: false,
                closedCaptions: true,
                openCaptions: false,
                transcript: false
            ).statements.map(\.id),
            [
                .richContentClosedCaptions,
            ]
        )

        XCTAssertEqual(
            RichContent(
                extendedAltTextDescriptions: false,
                mathFormula: false,
                mathFormulaAsMathML: false,
                mathFormulaAsLaTeX: false,
                chemicalFormulaAsMathML: false,
                chemicalFormulaAsLaTeX: false,
                closedCaptions: false,
                openCaptions: true,
                transcript: false
            ).statements.map(\.id),
            [
                .richContentOpenCaptions,
            ]
        )

        XCTAssertEqual(
            RichContent(
                extendedAltTextDescriptions: false,
                mathFormula: false,
                mathFormulaAsMathML: false,
                mathFormulaAsLaTeX: false,
                chemicalFormulaAsMathML: false,
                chemicalFormulaAsLaTeX: false,
                closedCaptions: false,
                openCaptions: false,
                transcript: true
            ).statements.map(\.id),
            [
                .richContentTranscript,
            ]
        )
    }

    func testAdditionalInformationInit() {
        func test(a11y: Accessibility?, expected: AdditionalInformation) {
            let sut = AdditionalInformation(publication: publication(accessibility: a11y))
            XCTAssertEqual(sut, expected)
        }

        // No additional information metadata
        test(a11y: nil, expected: AdditionalInformation(pageBreakMarkers: false, aria: false, audioDescriptions: false, braille: false, rubyAnnotations: false, fullRubyAnnotations: false, highAudioContrast: false, highDisplayContrast: false, largePrint: false, signLanguage: false, tactileGraphics: false, tactileObjects: false, textToSpeechHinting: false))
        test(a11y: .init(), expected: AdditionalInformation(pageBreakMarkers: false, aria: false, audioDescriptions: false, braille: false, rubyAnnotations: false, fullRubyAnnotations: false, highAudioContrast: false, highDisplayContrast: false, largePrint: false, signLanguage: false, tactileGraphics: false, tactileObjects: false, textToSpeechHinting: false))

        // Individual features
        test(a11y: .init(features: [.pageBreakMarkers]), expected: AdditionalInformation(pageBreakMarkers: true, aria: false, audioDescriptions: false, braille: false, rubyAnnotations: false, fullRubyAnnotations: false, highAudioContrast: false, highDisplayContrast: false, largePrint: false, signLanguage: false, tactileGraphics: false, tactileObjects: false, textToSpeechHinting: false))
        test(a11y: .init(features: [.printPageNumbers]), expected: AdditionalInformation(pageBreakMarkers: true, aria: false, audioDescriptions: false, braille: false, rubyAnnotations: false, fullRubyAnnotations: false, highAudioContrast: false, highDisplayContrast: false, largePrint: false, signLanguage: false, tactileGraphics: false, tactileObjects: false, textToSpeechHinting: false))
        test(a11y: .init(features: [.aria]), expected: AdditionalInformation(pageBreakMarkers: false, aria: true, audioDescriptions: false, braille: false, rubyAnnotations: false, fullRubyAnnotations: false, highAudioContrast: false, highDisplayContrast: false, largePrint: false, signLanguage: false, tactileGraphics: false, tactileObjects: false, textToSpeechHinting: false))
        test(a11y: .init(features: [.audioDescription]), expected: AdditionalInformation(pageBreakMarkers: false, aria: false, audioDescriptions: true, braille: false, rubyAnnotations: false, fullRubyAnnotations: false, highAudioContrast: false, highDisplayContrast: false, largePrint: false, signLanguage: false, tactileGraphics: false, tactileObjects: false, textToSpeechHinting: false))
        test(a11y: .init(features: [.braille]), expected: AdditionalInformation(pageBreakMarkers: false, aria: false, audioDescriptions: false, braille: true, rubyAnnotations: false, fullRubyAnnotations: false, highAudioContrast: false, highDisplayContrast: false, largePrint: false, signLanguage: false, tactileGraphics: false, tactileObjects: false, textToSpeechHinting: false))
        test(a11y: .init(features: [.rubyAnnotations]), expected: AdditionalInformation(pageBreakMarkers: false, aria: false, audioDescriptions: false, braille: false, rubyAnnotations: true, fullRubyAnnotations: false, highAudioContrast: false, highDisplayContrast: false, largePrint: false, signLanguage: false, tactileGraphics: false, tactileObjects: false, textToSpeechHinting: false))
        test(a11y: .init(features: [.fullRubyAnnotations]), expected: AdditionalInformation(pageBreakMarkers: false, aria: false, audioDescriptions: false, braille: false, rubyAnnotations: false, fullRubyAnnotations: true, highAudioContrast: false, highDisplayContrast: false, largePrint: false, signLanguage: false, tactileGraphics: false, tactileObjects: false, textToSpeechHinting: false))
        test(a11y: .init(features: [.highContrastAudio]), expected: AdditionalInformation(pageBreakMarkers: false, aria: false, audioDescriptions: false, braille: false, rubyAnnotations: false, fullRubyAnnotations: false, highAudioContrast: true, highDisplayContrast: false, largePrint: false, signLanguage: false, tactileGraphics: false, tactileObjects: false, textToSpeechHinting: false))
        test(a11y: .init(features: [.highContrastDisplay]), expected: AdditionalInformation(pageBreakMarkers: false, aria: false, audioDescriptions: false, braille: false, rubyAnnotations: false, fullRubyAnnotations: false, highAudioContrast: false, highDisplayContrast: true, largePrint: false, signLanguage: false, tactileGraphics: false, tactileObjects: false, textToSpeechHinting: false))
        test(a11y: .init(features: [.largePrint]), expected: AdditionalInformation(pageBreakMarkers: false, aria: false, audioDescriptions: false, braille: false, rubyAnnotations: false, fullRubyAnnotations: false, highAudioContrast: false, highDisplayContrast: false, largePrint: true, signLanguage: false, tactileGraphics: false, tactileObjects: false, textToSpeechHinting: false))
        test(a11y: .init(features: [.signLanguage]), expected: AdditionalInformation(pageBreakMarkers: false, aria: false, audioDescriptions: false, braille: false, rubyAnnotations: false, fullRubyAnnotations: false, highAudioContrast: false, highDisplayContrast: false, largePrint: false, signLanguage: true, tactileGraphics: false, tactileObjects: false, textToSpeechHinting: false))
        test(a11y: .init(features: [.tactileGraphic]), expected: AdditionalInformation(pageBreakMarkers: false, aria: false, audioDescriptions: false, braille: false, rubyAnnotations: false, fullRubyAnnotations: false, highAudioContrast: false, highDisplayContrast: false, largePrint: false, signLanguage: false, tactileGraphics: true, tactileObjects: false, textToSpeechHinting: false))
        test(a11y: .init(features: [.tactileObject]), expected: AdditionalInformation(pageBreakMarkers: false, aria: false, audioDescriptions: false, braille: false, rubyAnnotations: false, fullRubyAnnotations: false, highAudioContrast: false, highDisplayContrast: false, largePrint: false, signLanguage: false, tactileGraphics: false, tactileObjects: true, textToSpeechHinting: false))
        test(a11y: .init(features: [.ttsMarkup]), expected: AdditionalInformation(pageBreakMarkers: false, aria: false, audioDescriptions: false, braille: false, rubyAnnotations: false, fullRubyAnnotations: false, highAudioContrast: false, highDisplayContrast: false, largePrint: false, signLanguage: false, tactileGraphics: false, tactileObjects: false, textToSpeechHinting: true))

        // All features
        test(a11y: .init(features: [
            .pageBreakMarkers, .aria, .audioDescription, .braille,
            .rubyAnnotations, .fullRubyAnnotations, .highContrastAudio,
            .highContrastDisplay, .largePrint, .signLanguage, .tactileGraphic,
            .tactileObject, .ttsMarkup,
        ]), expected: AdditionalInformation(pageBreakMarkers: true, aria: true, audioDescriptions: true, braille: true, rubyAnnotations: true, fullRubyAnnotations: true, highAudioContrast: true, highDisplayContrast: true, largePrint: true, signLanguage: true, tactileGraphics: true, tactileObjects: true, textToSpeechHinting: true))
    }

    func testAdditionalInformationTitle() {
        XCTAssertEqual(AdditionalInformation().localizedTitle, "Additional accessibility information")
    }

    func testAdditionalInformationShouldDisplay() {
        // AdditionalInformation should be displayed only if there are some
        // metadata.
        let additionalInfoWithMetadata = AdditionalInformation(
            pageBreakMarkers: true,
            aria: false,
            audioDescriptions: false,
            braille: false,
            rubyAnnotations: false,
            fullRubyAnnotations: false,
            highAudioContrast: false,
            highDisplayContrast: false,
            largePrint: false,
            signLanguage: false,
            tactileGraphics: false,
            tactileObjects: false,
            textToSpeechHinting: false
        )
        XCTAssertTrue(additionalInfoWithMetadata.shouldDisplay)

        let additionalInfoWithoutMetadata = AdditionalInformation(
            pageBreakMarkers: false,
            aria: false,
            audioDescriptions: false,
            braille: false,
            rubyAnnotations: false,
            fullRubyAnnotations: false,
            highAudioContrast: false,
            highDisplayContrast: false,
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
            AdditionalInformation(
                pageBreakMarkers: false,
                aria: false,
                audioDescriptions: false,
                braille: false,
                rubyAnnotations: false,
                fullRubyAnnotations: false,
                highAudioContrast: false,
                highDisplayContrast: false,
                largePrint: false,
                signLanguage: false,
                tactileGraphics: false,
                tactileObjects: false,
                textToSpeechHinting: false
            ).statements.map(\.id),
            []
        )

        // Test when all features are enabled
        XCTAssertEqual(
            AdditionalInformation(
                pageBreakMarkers: true,
                aria: true,
                audioDescriptions: true,
                braille: true,
                rubyAnnotations: true,
                fullRubyAnnotations: true,
                highAudioContrast: true,
                highDisplayContrast: true,
                largePrint: true,
                signLanguage: true,
                tactileGraphics: true,
                tactileObjects: true,
                textToSpeechHinting: true
            ).statements.map(\.id),
            [
                .additionalAccessibilityInformationPageBreaks,
                .additionalAccessibilityInformationAria,
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
            AdditionalInformation(
                pageBreakMarkers: true,
                aria: false,
                audioDescriptions: false,
                braille: false,
                rubyAnnotations: false,
                fullRubyAnnotations: false,
                highAudioContrast: false,
                highDisplayContrast: false,
                largePrint: false,
                signLanguage: false,
                tactileGraphics: false,
                tactileObjects: false,
                textToSpeechHinting: false
            ).statements.map(\.id),
            [
                .additionalAccessibilityInformationPageBreaks,
            ]
        )

        XCTAssertEqual(
            AdditionalInformation(
                pageBreakMarkers: false,
                aria: true,
                audioDescriptions: false,
                braille: false,
                rubyAnnotations: false,
                fullRubyAnnotations: false,
                highAudioContrast: false,
                highDisplayContrast: false,
                largePrint: false,
                signLanguage: false,
                tactileGraphics: false,
                tactileObjects: false,
                textToSpeechHinting: false
            ).statements.map(\.id),
            [
                .additionalAccessibilityInformationAria,
            ]
        )

        XCTAssertEqual(
            AdditionalInformation(
                pageBreakMarkers: false,
                aria: false,
                audioDescriptions: true,
                braille: false,
                rubyAnnotations: false,
                fullRubyAnnotations: false,
                highAudioContrast: false,
                highDisplayContrast: false,
                largePrint: false,
                signLanguage: false,
                tactileGraphics: false,
                tactileObjects: false,
                textToSpeechHinting: false
            ).statements.map(\.id),
            [
                .additionalAccessibilityInformationAudioDescriptions,
            ]
        )

        XCTAssertEqual(
            AdditionalInformation(
                pageBreakMarkers: false,
                aria: false,
                audioDescriptions: false,
                braille: true,
                rubyAnnotations: false,
                fullRubyAnnotations: false,
                highAudioContrast: false,
                highDisplayContrast: false,
                largePrint: false,
                signLanguage: false,
                tactileGraphics: false,
                tactileObjects: false,
                textToSpeechHinting: false
            ).statements.map(\.id),
            [
                .additionalAccessibilityInformationBraille,
            ]
        )

        // Additional tests for each feature
        XCTAssertEqual(
            AdditionalInformation(
                pageBreakMarkers: false,
                aria: false,
                audioDescriptions: false,
                braille: false,
                rubyAnnotations: true,
                fullRubyAnnotations: false,
                highAudioContrast: false,
                highDisplayContrast: false,
                largePrint: false,
                signLanguage: false,
                tactileGraphics: false,
                tactileObjects: false,
                textToSpeechHinting: false
            ).statements.map(\.id),
            [
                .additionalAccessibilityInformationRubyAnnotations,
            ]
        )

        XCTAssertEqual(
            AdditionalInformation(
                pageBreakMarkers: false,
                aria: false,
                audioDescriptions: false,
                braille: false,
                rubyAnnotations: false,
                fullRubyAnnotations: true,
                highAudioContrast: false,
                highDisplayContrast: false,
                largePrint: false,
                signLanguage: false,
                tactileGraphics: false,
                tactileObjects: false,
                textToSpeechHinting: false
            ).statements.map(\.id),
            [
                .additionalAccessibilityInformationFullRubyAnnotations,
            ]
        )

        XCTAssertEqual(
            AdditionalInformation(
                pageBreakMarkers: false,
                aria: false,
                audioDescriptions: false,
                braille: false,
                rubyAnnotations: false,
                fullRubyAnnotations: false,
                highAudioContrast: true,
                highDisplayContrast: false,
                largePrint: false,
                signLanguage: false,
                tactileGraphics: false,
                tactileObjects: false,
                textToSpeechHinting: false
            ).statements.map(\.id),
            [
                .additionalAccessibilityInformationHighContrastBetweenForegroundAndBackgroundAudio,
            ]
        )

        XCTAssertEqual(
            AdditionalInformation(
                pageBreakMarkers: false,
                aria: false,
                audioDescriptions: false,
                braille: false,
                rubyAnnotations: false,
                fullRubyAnnotations: false,
                highAudioContrast: false,
                highDisplayContrast: true,
                largePrint: false,
                signLanguage: false,
                tactileGraphics: false,
                tactileObjects: false,
                textToSpeechHinting: false
            ).statements.map(\.id),
            [
                .additionalAccessibilityInformationHighContrastBetweenTextAndBackground,
            ]
        )

        XCTAssertEqual(
            AdditionalInformation(
                pageBreakMarkers: false,
                aria: false,
                audioDescriptions: false,
                braille: false,
                rubyAnnotations: false,
                fullRubyAnnotations: false,
                highAudioContrast: false,
                highDisplayContrast: false,
                largePrint: true,
                signLanguage: false,
                tactileGraphics: false,
                tactileObjects: false,
                textToSpeechHinting: false
            ).statements.map(\.id),
            [
                .additionalAccessibilityInformationLargePrint,
            ]
        )

        XCTAssertEqual(
            AdditionalInformation(
                pageBreakMarkers: false,
                aria: false,
                audioDescriptions: false,
                braille: false,
                rubyAnnotations: false,
                fullRubyAnnotations: false,
                highAudioContrast: false,
                highDisplayContrast: false,
                largePrint: false,
                signLanguage: true,
                tactileGraphics: false,
                tactileObjects: false,
                textToSpeechHinting: false
            ).statements.map(\.id),
            [
                .additionalAccessibilityInformationSignLanguage,
            ]
        )

        XCTAssertEqual(
            AdditionalInformation(
                pageBreakMarkers: false,
                aria: false,
                audioDescriptions: false,
                braille: false,
                rubyAnnotations: false,
                fullRubyAnnotations: false,
                highAudioContrast: false,
                highDisplayContrast: false,
                largePrint: false,
                signLanguage: false,
                tactileGraphics: true,
                tactileObjects: false,
                textToSpeechHinting: false
            ).statements.map(\.id),
            [
                .additionalAccessibilityInformationTactileGraphics,
            ]
        )

        XCTAssertEqual(
            AdditionalInformation(
                pageBreakMarkers: false,
                aria: false,
                audioDescriptions: false,
                braille: false,
                rubyAnnotations: false,
                fullRubyAnnotations: false,
                highAudioContrast: false,
                highDisplayContrast: false,
                largePrint: false,
                signLanguage: false,
                tactileGraphics: false,
                tactileObjects: true,
                textToSpeechHinting: false
            ).statements.map(\.id),
            [
                .additionalAccessibilityInformationTactileObjects,
            ]
        )

        XCTAssertEqual(
            AdditionalInformation(
                pageBreakMarkers: false,
                aria: false,
                audioDescriptions: false,
                braille: false,
                rubyAnnotations: false,
                fullRubyAnnotations: false,
                highAudioContrast: false,
                highDisplayContrast: false,
                largePrint: false,
                signLanguage: false,
                tactileGraphics: false,
                tactileObjects: false,
                textToSpeechHinting: true
            ).statements.map(\.id),
            [
                .additionalAccessibilityInformationTextToSpeechHinting,
            ]
        )
    }

    func testHazardsInit() {
        func test(a11y: Accessibility?, expected: Hazards) {
            let sut = Hazards(publication: publication(accessibility: a11y))
            XCTAssertEqual(sut, expected)
        }

        // No hazards metadata
        test(a11y: nil, expected: Hazards(flashing: .noMetadata, motion: .noMetadata, sound: .noMetadata))
        test(a11y: .init(), expected: Hazards(flashing: .noMetadata, motion: .noMetadata, sound: .noMetadata))

        // Declared no hazards
        test(a11y: .init(hazards: [.none]), expected: Hazards(flashing: .no, motion: .no, sound: .no))
        test(a11y: .init(hazards: [.none, .flashing]), expected: Hazards(flashing: .yes, motion: .no, sound: .no))
        test(a11y: .init(hazards: [.none, .motionSimulation]), expected: Hazards(flashing: .no, motion: .yes, sound: .no))
        test(a11y: .init(hazards: [.none, .unknownSoundHazard]), expected: Hazards(flashing: .no, motion: .no, sound: .unknown))

        // Declared unknown hazards
        test(a11y: .init(hazards: [.unknown]), expected: Hazards(flashing: .unknown, motion: .unknown, sound: .unknown))
        test(a11y: .init(hazards: [.unknown, .flashing]), expected: Hazards(flashing: .yes, motion: .unknown, sound: .unknown))
        test(a11y: .init(hazards: [.unknown, .motionSimulation]), expected: Hazards(flashing: .unknown, motion: .yes, sound: .unknown))
        test(a11y: .init(hazards: [.unknown, .noSoundHazard]), expected: Hazards(flashing: .unknown, motion: .unknown, sound: .no))

        // Flashing
        test(a11y: .init(hazards: [.flashing]), expected: Hazards(flashing: .yes, motion: .noMetadata, sound: .noMetadata))
        test(a11y: .init(hazards: [.noFlashingHazard]), expected: Hazards(flashing: .no, motion: .noMetadata, sound: .noMetadata))
        test(a11y: .init(hazards: [.unknownFlashingHazard]), expected: Hazards(flashing: .unknown, motion: .noMetadata, sound: .noMetadata))

        // Motion
        test(a11y: .init(hazards: [.motionSimulation]), expected: Hazards(flashing: .noMetadata, motion: .yes, sound: .noMetadata))
        test(a11y: .init(hazards: [.noMotionSimulationHazard]), expected: Hazards(flashing: .noMetadata, motion: .no, sound: .noMetadata))
        test(a11y: .init(hazards: [.unknownMotionSimulationHazard]), expected: Hazards(flashing: .noMetadata, motion: .unknown, sound: .noMetadata))

        // Sound
        test(a11y: .init(hazards: [.sound]), expected: Hazards(flashing: .noMetadata, motion: .noMetadata, sound: .yes))
        test(a11y: .init(hazards: [.noSoundHazard]), expected: Hazards(flashing: .noMetadata, motion: .noMetadata, sound: .no))
        test(a11y: .init(hazards: [.unknownSoundHazard]), expected: Hazards(flashing: .noMetadata, motion: .noMetadata, sound: .unknown))

        // Combination of hazards
        test(a11y: .init(hazards: [.flashing, .noSoundHazard]), expected: Hazards(flashing: .yes, motion: .noMetadata, sound: .no))
        test(a11y: .init(hazards: [.unknownFlashingHazard, .noSoundHazard, .motionSimulation]), expected: Hazards(flashing: .unknown, motion: .yes, sound: .no))
    }

    func testHazardsTitle() {
        XCTAssertEqual(Hazards().localizedTitle, "Hazards")
    }

    func testHazardsShouldDisplay() {
        // Hazards should be hidden only if no metadata is provided
        let hazardsWithMetadata = Hazards(
            flashing: .yes,
            motion: .noMetadata,
            sound: .noMetadata
        )
        XCTAssertTrue(hazardsWithMetadata.shouldDisplay)

        let hazardsWithoutMetadata = Hazards(
            flashing: .noMetadata,
            motion: .noMetadata,
            sound: .noMetadata
        )
        XCTAssertFalse(hazardsWithoutMetadata.shouldDisplay)
    }

    func testHazardsStatements() {
        // Test when noMetadata is true
        XCTAssertEqual(
            Hazards(
                flashing: .noMetadata,
                motion: .noMetadata,
                sound: .noMetadata
            ).statements.map(\.id),
            [
                .hazardsNoMetadata,
            ]
        )

        // Test when no hazards are present
        XCTAssertEqual(
            Hazards(
                flashing: .no,
                motion: .no,
                sound: .no
            ).statements.map(\.id),
            [
                .hazardsNone,
            ]
        )

        // Test when hazards are unknown
        XCTAssertEqual(
            Hazards(
                flashing: .unknown,
                motion: .unknown,
                sound: .unknown
            ).statements.map(\.id),
            [
                .hazardsUnknown,
            ]
        )

        // Test individual hazards
        XCTAssertEqual(
            Hazards(
                flashing: .yes,
                motion: .no,
                sound: .no
            ).statements.map(\.id),
            [
                .hazardsFlashing,
                .hazardsMotionNone,
                .hazardsSoundNone,
            ]
        )

        XCTAssertEqual(
            Hazards(
                flashing: .no,
                motion: .yes,
                sound: .no
            ).statements.map(\.id),
            [
                .hazardsMotion,
                .hazardsFlashingNone,
                .hazardsSoundNone,
            ]
        )

        XCTAssertEqual(
            Hazards(
                flashing: .no,
                motion: .no,
                sound: .yes
            ).statements.map(\.id),
            [
                .hazardsSound,
                .hazardsFlashingNone,
                .hazardsMotionNone,
            ]
        )

        // Test combinations of hazards
        XCTAssertEqual(
            Hazards(
                flashing: .yes,
                motion: .yes,
                sound: .yes
            ).statements.map(\.id),
            [
                .hazardsFlashing,
                .hazardsMotion,
                .hazardsSound,
            ]
        )

        XCTAssertEqual(
            Hazards(
                flashing: .unknown,
                motion: .yes,
                sound: .no
            ).statements.map(\.id),
            [
                .hazardsMotion,
                .hazardsFlashingUnknown,
                .hazardsSoundNone,
            ]
        )

        XCTAssertEqual(
            Hazards(
                flashing: .yes,
                motion: .unknown,
                sound: .unknown
            ).statements.map(\.id),
            [
                .hazardsFlashing,
                .hazardsMotionUnknown,
                .hazardsSoundUnknown,
            ]
        )
    }

    func testConformanceInit() {
        func test(a11y: Accessibility?, expected: Conformance) {
            let sut = Conformance(publication: publication(accessibility: a11y))
            XCTAssertEqual(sut, expected)
        }

        // No metadata or profile
        test(a11y: nil, expected: Conformance(profiles: []))
        test(a11y: .init(conformsTo: []), expected: Conformance(profiles: []))

        // One profile
        test(a11y: .init(conformsTo: [.epubA11y10WCAG20A]), expected: Conformance(profiles: [.epubA11y10WCAG20A]))

        // Multiple profiles
        test(a11y: .init(conformsTo: [.epubA11y10WCAG20A, .epubA11y11WCAG20A]), expected: Conformance(profiles: [.epubA11y10WCAG20A, .epubA11y11WCAG20A]))
    }

    func testConformanceTitle() {
        XCTAssertEqual(Conformance().localizedTitle, "Conformance")
    }

    func testConformanceShouldDisplay() {
        // Conformance should always be displayed
        XCTAssertTrue(Conformance(profiles: []).shouldDisplay)
        XCTAssertTrue(Conformance(profiles: [.epubA11y10WCAG20A]).shouldDisplay)
    }

    func testConformanceStatements() {
        func test(_ profiles: [Accessibility.Profile], expected: AccessibilityDisplayString) {
            XCTAssertEqual(
                Conformance(profiles: profiles).statements.map(\.id),
                [expected]
            )
        }

        // Test no profile
        test([], expected: .conformanceNo)
        // Test unknown profile
        test([.init("https://custom-profile")], expected: .conformanceUnknownStandard)
        // Test level A profiles
        test([.epubA11y10WCAG20A], expected: .conformanceA)
        test([.epubA11y11WCAG20A], expected: .conformanceA)
        test([.epubA11y11WCAG21A], expected: .conformanceA)
        test([.epubA11y11WCAG22A], expected: .conformanceA)
        // Test level AA profiles
        test([.epubA11y10WCAG20AA], expected: .conformanceAa)
        test([.epubA11y11WCAG20AA], expected: .conformanceAa)
        test([.epubA11y11WCAG21AA], expected: .conformanceAa)
        test([.epubA11y11WCAG22AA], expected: .conformanceAa)
        // Test level AAA profiles
        test([.epubA11y10WCAG20AAA], expected: .conformanceAaa)
        test([.epubA11y11WCAG20AAA], expected: .conformanceAaa)
        test([.epubA11y11WCAG21AAA], expected: .conformanceAaa)
        test([.epubA11y11WCAG22AAA], expected: .conformanceAaa)
        // Test multiple profiles
        test([.epubA11y10WCAG20A, .epubA11y10WCAG20AA, .epubA11y10WCAG20AAA], expected: .conformanceAaa)
        test([.epubA11y10WCAG20A, .epubA11y10WCAG20AA], expected: .conformanceAa)
    }

    func testLegalInit() {
        func test(a11y: Accessibility?, expected: Legal) {
            let sut = Legal(publication: publication(accessibility: a11y))
            XCTAssertEqual(sut, expected)
        }

        // No metadata or exemptions
        test(a11y: nil, expected: Legal(exemption: false))
        test(a11y: .init(exemptions: []), expected: Legal(exemption: false))

        // Exemptions
        test(a11y: .init(exemptions: [.eaaDisproportionateBurden]), expected: Legal(exemption: true))
        test(a11y: .init(exemptions: [.eaaFundamentalAlteration]), expected: Legal(exemption: true))
        test(a11y: .init(exemptions: [.eaaMicroenterprise]), expected: Legal(exemption: true))
        test(a11y: .init(exemptions: [.eaaMicroenterprise, .eaaFundamentalAlteration]), expected: Legal(exemption: true))
    }

    func testLegalTitle() {
        XCTAssertEqual(Legal().localizedTitle, "Legal considerations")
    }

    func testLegalShouldDisplay() {
        // Legal should be displayed only if there is an exemption.
        XCTAssertTrue(Legal(exemption: true).shouldDisplay)
        XCTAssertFalse(Legal(exemption: false).shouldDisplay)
    }

    func testLegalStatements() {
        // Test when noMetadata is true
        XCTAssertEqual(
            Legal(exemption: false).statements.map(\.id),
            [
                .legalConsiderationsNoMetadata,
            ]
        )

        // Test when exemption is claimed
        XCTAssertEqual(
            Legal(exemption: true).statements.map(\.id),
            [
                .legalConsiderationsExempt,
            ]
        )
    }

    func testAccessibilitySummaryInit() {
        func test(a11y: Accessibility?, expected: AccessibilitySummary) {
            let sut = AccessibilitySummary(publication: publication(accessibility: a11y))
            XCTAssertEqual(sut, expected)
        }

        test(a11y: nil, expected: AccessibilitySummary(summary: nil))
        test(a11y: .init(summary: nil), expected: AccessibilitySummary(summary: nil))
        test(a11y: .init(summary: "A summary"), expected: AccessibilitySummary(summary: "A summary"))
    }

    func testAccessibilitySummaryTitle() {
        XCTAssertEqual(AccessibilitySummary().localizedTitle, "Accessibility summary")
    }

    func testAccessibilitySummaryShouldDisplay() {
        // AccessibilitySummary should be displayed only if summary is not nil
        let summaryWithContent = AccessibilitySummary(summary: "This is a summary.")
        XCTAssertTrue(summaryWithContent.shouldDisplay)

        let summaryWithoutContent = AccessibilitySummary(summary: nil)
        XCTAssertFalse(summaryWithoutContent.shouldDisplay)
    }

    func testAccessibilitySummaryStatements() {
        // Test when summary is nil
        XCTAssertEqual(
            AccessibilitySummary(summary: nil).statements.map(\.id),
            [
                .accessibilitySummaryNoMetadata,
            ]
        )

        // Test when summary is provided
        let summaryText = "This publication is accessible and includes features such as text-to-speech and high contrast."
        let fields = AccessibilitySummary(summary: summaryText).statements
        XCTAssertEqual(fields.count, 1)
        let field = fields[0]
        XCTAssertEqual(field.id, .accessibilitySummary)
        XCTAssertEqual(field.localizedString(descriptive: false).string, summaryText)
        XCTAssertEqual(field.localizedString(descriptive: true).string, summaryText)
    }

    private func publication(
        layout: Layout? = nil,
        accessibility: Accessibility?
    ) -> Publication {
        Publication(
            manifest: Manifest(
                metadata: Metadata(
                    accessibility: accessibility,
                    layout: layout
                )
            )
        )
    }
}
