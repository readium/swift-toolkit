//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import XCTest
@testable import R2Shared

class AccessibilityTests: XCTestCase {

    func testParseMinimalJSON() {
        XCTAssertEqual(
            try? Accessibility(json: [:]),
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
                    "report": "https://report1"
                ],
                "summary": "Summary",
                "accessMode": ["auditory", "chartOnVisual"],
                "accessModeSufficient": [["visual", "tactile"]],
                "feature": ["readingOrder", "alternativeText"],
                "hazard": ["flashing", "motionSimulation"]
            ]),
            Accessibility(
                conformsTo: [
                    Accessibility.Profile("https://profile1"),
                    Accessibility.Profile("https://profile2")
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
                hazards: [.flashing, .motionSimulation]
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
                "accessModeSufficient": ["auditory", ["visual"]],
            ]),
            Accessibility(
                accessModesSufficient: [[.auditory], [.visual]]
            )
        )
        XCTAssertEqual(
            try? Accessibility(json: [
                "accessModeSufficient": ["auditory", ["visual", "tactile"], [], "visual"],
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

    func testGetMinimalJSON() {
        AssertJSONEqual(
            Accessibility().json,
            [:]
        )
    }

    func testGetFullJSON() {
        let expected = Accessibility(
            conformsTo: [
                .epubA11y10WCAG20A,
                Accessibility.Profile("https://profile2")
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
            hazards: [.flashing, .motionSimulation]
        ).json
        AssertJSONEqual(
            expected,
            [
                "conformsTo": ["http://www.idpf.org/epub/a11y/accessibility-20170105.html#wcag-a", "https://profile2"],
                "certification": [
                    "certifiedBy": "company1",
                    "credential": "credential1",
                    "report": "https://report1"
                ],
                "summary": "Summary",
                "accessMode": ["auditory", "chartOnVisual"],
                "accessModeSufficient": [["auditory"], ["visual", "tactile"], ["visual"]],
                "feature": ["readingOrder", "alternativeText"],
                "hazard": ["flashing", "motionSimulation"]
            ]
        )
    }
}
