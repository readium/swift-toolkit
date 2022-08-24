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
                "conformsTo": "profile1",
                "certification": [
                    "certifiedBy": "company1",
                    "credential": "credential1",
                    "report": "report1"
                ],
                "summary": "Summary",
                "accessMode": ["auditory"],
                "accessModeSufficient": ["visual"],
                "feature": ["readingOrder"],
                "hazard": ["flashing"]
            ]),
            Accessibility(
                conformsTo: ["profile1"],
                certification: Accessibility.Certification(
                    certifiedBy: ["company1"],
                    credentials: ["credential1"],
                    reports: ["report1"]
                ),
                summary: "Summary",
                accessModes: [.auditory],
                accessModesSufficient: [.visual],
                features: [.readingOrder],
                hazards: [.flashing]
            )
        )
    }

    func testParseFullJSONWithStringArrays() {
        XCTAssertEqual(
            try? Accessibility(json: [
                "conformsTo": ["profile1", "profile2"],
                "certification": [
                    "certifiedBy": ["company1", "company2"],
                    "credential": ["credential1", "credential2"],
                    "report": ["report1", "report2"]
                ],
                "summary": "Summary",
                "accessMode": ["auditory", "chartOnVisual"],
                "accessModeSufficient": ["visual", "tactile"],
                "feature": ["readingOrder", "alternativeText"],
                "hazard": ["flashing", "motionSimulation"]
            ]),
            Accessibility(
                conformsTo: ["profile1", "profile2"],
                certification: Accessibility.Certification(
                    certifiedBy: ["company1", "company2"],
                    credentials: ["credential1", "credential2"],
                    reports: ["report1", "report2"]
                ),
                summary: "Summary",
                accessModes: [.auditory, .chartOnVisual],
                accessModesSufficient: [.visual, .tactile],
                features: [.readingOrder, .alternativeText],
                hazards: [.flashing, .motionSimulation]
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
                conformsTo: ["profile1", "profile2"],
                certification: Accessibility.Certification(
                    certifiedBy: ["company1", "company2"],
                    credentials: ["credential1", "credential2"],
                    reports: ["report1", "report2"]
                ),
                summary: "Summary",
                accessModes: [.auditory, .chartOnVisual],
                accessModesSufficient: [.visual, .tactile],
                features: [.readingOrder, .alternativeText],
                hazards: [.flashing, .motionSimulation]
            ).json,
            [
                "conformsTo": ["profile1", "profile2"],
                "certification": [
                    "certifiedBy": ["company1", "company2"],
                    "credential": ["credential1", "credential2"],
                    "report": ["report1", "report2"]
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
