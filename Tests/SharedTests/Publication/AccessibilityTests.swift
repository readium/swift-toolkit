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

    func testParseFullJSONWithStrings() {
        XCTAssertEqual(
            try? Accessibility(json: [
                "conformsTo": "https://profile1",
                "certification": [
                    "certifiedBy": "company1",
                    "credential": "credential1",
                    "report": "https://report1"
                ],
                "summary": "Summary",
                "accessMode": ["auditory"],
                "accessModeSufficient": ["visual"],
                "feature": ["readingOrder"],
                "hazard": ["flashing"]
            ]),
            Accessibility(
                conformsTo: ["https://profile1"],
                certification: Accessibility.Certification(
                    certifiedBy: "company1",
                    credentials: "credential1",
                    reports: URL(string: "https://report1")!
                ),
                summary: "Summary",
                accessModes: [.auditory],
                accessModesSufficient: [.visual],
                features: [.readingOrder],
                hazards: [.flashing]
            )
        )
    }

    func testParseFullJSONWithMultipleStrings() {
        XCTAssertEqual(
            try? Accessibility(json: [
                "conformsTo": ["https://profile1", "https://profile2"],
                "accessMode": ["auditory", "chartOnVisual"],
                "accessModeSufficient": ["visual", "tactile"],
                "feature": ["readingOrder", "alternativeText"],
                "hazard": ["flashing", "motionSimulation"]
            ]),
            Accessibility(
                conformsTo: ["https://profile1", "https://profile2"],
                accessModes: [.auditory, .chartOnVisual],
                accessModesSufficient: [.visual, .tactile],
                features: [.readingOrder, .alternativeText],
                hazards: [.flashing, .motionSimulation]
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
