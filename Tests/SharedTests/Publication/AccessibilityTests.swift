//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import XCTest

class AccessibilityTests: XCTestCase {
    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? Accessibility(json: [:] as [String: Any]),
            Accessibility()
        )
    }

    func testParseInvalidJSON() {
        XCTAssertThrowsError(try Accessibility(json: "invalid"))
    }

    func testParseFullJSON() {
        XCTAssertEqual(
            try? Accessibility(json: [
                "conformsTo": ["https://profile1", "https://profile2"],
                "certification": [
                    "certifiedBy": "company1",
                    "credential": "credential1",
                    "report": "https://report1",
                ],
                "summary": "Summary",
                "accessMode": ["auditory", "chartOnVisual"],
                "accessModeSufficient": [["visual", "tactile"]],
                "feature": ["readingOrder", "alternativeText"],
                "hazard": ["flashing", "motionSimulation"],
                "exemption": ["eaa-fundamental-alteration", "eaa-microenterprise"],
            ] as [String: Any]),
            Accessibility(
                conformsTo: [
                    Accessibility.Profile("https://profile1"),
                    Accessibility.Profile("https://profile2"),
                ],
                certification: Accessibility.Certification(
                    certifiedBy: "company1",
                    credential: "credential1",
                    report: "https://report1"
                ),
                summary: "Summary",
                accessModes: [.auditory, .chartOnVisual],
                accessModesSufficient: [[.visual, .tactile]],
                features: [.readingOrder, .alternativeText],
                hazards: [.flashing, .motionSimulation],
                exemptions: [.eaaFundamentalAlteration, .eaaMicroenterprise]
            )
        )
    }

    func testParseConformsTo() {
        XCTAssertEqual(
            try? Accessibility(json: [
                "conformsTo": "http://www.idpf.org/epub/a11y/accessibility-20170105.html#wcag-a",
            ]),
            Accessibility(
                conformsTo: [.epubA11y10WCAG20A]
            )
        )
        XCTAssertEqual(
            try? Accessibility(json: [
                "conformsTo": ["http://www.idpf.org/epub/a11y/accessibility-20170105.html#wcag-a", "https://profile2"],
            ]),
            Accessibility(
                conformsTo: [.epubA11y10WCAG20A, Accessibility.Profile("https://profile2")]
            )
        )
    }

    func testParseAccessMode() {
        XCTAssertEqual(
            try? Accessibility(json: [
                "accessMode": ["auditory"],
            ]),
            Accessibility(
                accessModes: [.auditory]
            )
        )
        XCTAssertEqual(
            try? Accessibility(json: [
                "accessMode": ["auditory", "chartOnVisual", "chemOnVisual"],
            ]),
            Accessibility(
                accessModes: [.auditory, .chartOnVisual, .chemOnVisual]
            )
        )
    }

    func testParseAccessModeSufficient() {
        XCTAssertEqual(
            try? Accessibility(json: [
                "accessModeSufficient": ["auditory"],
            ]),
            Accessibility(
                accessModesSufficient: [[.auditory]]
            )
        )
        XCTAssertEqual(
            try? Accessibility(json: [
                "accessModeSufficient": ["auditory", "visual"],
            ]),
            Accessibility(
                accessModesSufficient: [[.auditory], [.visual]]
            )
        )
        XCTAssertEqual(
            try? Accessibility(json: [
                "accessModeSufficient": ["auditory", ["visual"]] as [Any],
            ]),
            Accessibility(
                accessModesSufficient: [[.auditory], [.visual]]
            )
        )
        XCTAssertEqual(
            try? Accessibility(json: [
                "accessModeSufficient": ["auditory", ["visual", "tactile"], [] as [String], "visual"] as [Any],
            ]),
            Accessibility(
                accessModesSufficient: [[.auditory], [.visual, .tactile], [.visual]]
            )
        )
    }

    func testParseFeatures() {
        XCTAssertEqual(
            try? Accessibility(json: [
                "feature": ["index"],
            ]),
            Accessibility(
                features: [.index]
            )
        )
        XCTAssertEqual(
            try? Accessibility(json: [
                "feature": ["index", "ARIA", "annotations"],
            ]),
            Accessibility(
                features: [.index, .aria, .annotations]
            )
        )
    }

    func testParseHazards() {
        XCTAssertEqual(
            try? Accessibility(json: [
                "hazard": ["flashing"],
            ]),
            Accessibility(
                hazards: [.flashing]
            )
        )
        XCTAssertEqual(
            try? Accessibility(json: [
                "hazard": ["flashing", "noSoundHazard", "motionSimulation"],
            ]),
            Accessibility(
                hazards: [.flashing, .noSoundHazard, .motionSimulation]
            )
        )
    }

    func testParseExemptions() {
        XCTAssertEqual(
            try? Accessibility(json: [
                "exemption": ["eaa-microenterprise"],
            ]),
            Accessibility(
                exemptions: [.eaaMicroenterprise]
            )
        )
        XCTAssertEqual(
            try? Accessibility(json: [
                "exemption": ["eaa-disproportionate-burden", "eaa-microenterprise"],
            ]),
            Accessibility(
                exemptions: [.eaaDisproportionateBurden, .eaaMicroenterprise]
            )
        )
    }

    func testGetMinimalJSON() {
        AssertJSONEqual(
            Accessibility().json,
            [:] as [String: Any]
        )
    }

    func testGetFullJSON() {
        let expected = Accessibility(
            conformsTo: [
                .epubA11y10WCAG20A,
                Accessibility.Profile("https://profile2"),
            ],
            certification: Accessibility.Certification(
                certifiedBy: "company1",
                credential: "credential1",
                report: "https://report1"
            ),
            summary: "Summary",
            accessModes: [.auditory, .chartOnVisual],
            accessModesSufficient: [[.auditory], [.visual, .tactile], [.visual]],
            features: [.readingOrder, .alternativeText],
            hazards: [.flashing, .motionSimulation],
            exemptions: [.eaaDisproportionateBurden, .eaaMicroenterprise]
        ).json
        AssertJSONEqual(
            expected,
            [
                "conformsTo": ["http://www.idpf.org/epub/a11y/accessibility-20170105.html#wcag-a", "https://profile2"],
                "certification": [
                    "certifiedBy": "company1",
                    "credential": "credential1",
                    "report": "https://report1",
                ],
                "summary": "Summary",
                "accessMode": ["auditory", "chartOnVisual"],
                "accessModeSufficient": [["auditory"], ["visual", "tactile"], ["visual"]],
                "feature": ["readingOrder", "alternativeText"],
                "hazard": ["flashing", "motionSimulation"],
                "exemption": ["eaa-disproportionate-burden", "eaa-microenterprise"],
            ] as [String: Any]
        )
    }
}
