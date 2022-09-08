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
                "accessModeSufficient": ["visual", "tactile"],
                "feature": ["readingOrder", "alternativeText"],
                "hazard": ["flashing", "motionSimulation"]
            ]),
            Accessibility(
                conformsTo: ["https://profile1", "https://profile2"],
                certification: Accessibility.Certification(
                    certifiedBy: "company1",
                    credentials: "credential1",
                    reports: URL(string: "https://report1")!
                ),
                summary: "Summary",
                accessModes: [.auditory, .chartOnVisual],
                accessModesSufficient: [.visual, .tactile],
                features: [.readingOrder, .alternativeText],
                hazards: [.flashing, .motionSimulation]
            )
        )
    }

    func testParseConformsTo() {
        XCTAssertEqual(
            try? Accessibility(json: [
                "conformsTo": "https://profile1",
            ]),
            Accessibility(
                conformsTo: ["https://profile1"]
            )
        )
        XCTAssertEqual(
            try? Accessibility(json: [
                "conformsTo": ["https://profile1", "https://profile2"],
            ]),
            Accessibility(
                conformsTo: ["https://profile1", "https://profile2"]
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
                accessModesSufficient: [.auditory]
            )
        )
        XCTAssertEqual(
            try? Accessibility(json: [
                "accessModeSufficient": ["auditory", "visual"],
            ]),
            Accessibility(
                accessModesSufficient: [.auditory, .visual]
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

    func testParseIgnoreInvalidReport() {
        XCTAssertEqual(
            try? Accessibility(json: [
                "certification": [
                    "certifiedBy": "company1",
                    "report": "report1"
                ],
            ]),
            Accessibility(
                certification: Accessibility.Certification(
                    certifiedBy: "company1"
                )
            )
        )
        XCTAssertEqual(
            try? Accessibility(json: [
                "certification": [
                    "report": "report1"
                ],
            ]),
            Accessibility(
                certification: nil
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
        AssertJSONEqual(
            Accessibility(
                conformsTo: ["https://profile1", "https://profile2"],
                certification: Accessibility.Certification(
                    certifiedBy: "company1",
                    credentials: "credential1",
                    reports: URL(string: "https://report1")!
                ),
                summary: "Summary",
                accessModes: [.auditory, .chartOnVisual],
                accessModesSufficient: [.visual, .tactile],
                features: [.readingOrder, .alternativeText],
                hazards: [.flashing, .motionSimulation]
            ).json,
            [
                "conformsTo": ["https://profile1", "https://profile2"],
                "certification": [
                    "certifiedBy": "company1",
                    "credential": "credential1",
                    "report": "https://report1"
                ],
                "summary": "Summary",
                "accessMode": ["auditory", "chartOnVisual"],
                "accessModeSufficient": ["visual", "tactile"],
                "feature": ["readingOrder", "alternativeText"],
                "hazard": ["flashing", "motionSimulation"]
            ]
        )
    }
}
