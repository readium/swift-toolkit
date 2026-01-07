//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import XCTest

extension XCUIElementQuery {
    subscript(id: AccessibilityID) -> XCUIElement {
        self[id.rawValue]
    }
}

extension XCUIElement {
    var stringValue: String? {
        value as? String
    }

    func assertIsOn() {
        assertIs(true)
    }

    func assertIsOff() {
        assertIs(false)
    }

    func assertIs(_ on: Bool, waitForTimeout timeout: TimeInterval? = nil) {
        let expectedValue = on ? "1" : "0"
        let message = "Expected to be \(on ? "on" : "off")"

        if let timeout = timeout {
            XCTAssertTrue(wait(toBe: on, timeout: timeout), message)
        } else {
            XCTAssertEqual(stringValue, expectedValue, message)
        }
    }

    func wait(toBe on: Bool, timeout: TimeInterval) -> Bool {
        let expectedValue = on ? "1" : "0"
        return wait(for: \.stringValue, toEqual: expectedValue, timeout: timeout)
    }
}
