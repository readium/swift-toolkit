//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumShared
import Testing

struct ComparableTests {
    @Test(arguments: [
        (1.5, 1.5),
        (0.01, 0.01),
        (0.0, nil),
        (-0.0, nil),
        (-1.0, nil),
        (Double.infinity, Double.infinity),
        (-Double.infinity, nil),
    ] as [(Double, Double?)])
    func positiveOrNilDouble(value: Double, expected: Double?) {
        #expect(value.positiveOrNil == expected)
    }

    @Test func positiveOrNilNaN() {
        #expect(Double.nan.positiveOrNil == nil)
    }

    @Test func positiveOrNilInt() {
        #expect(2.positiveOrNil == 2)
        #expect(0.positiveOrNil == nil)
        #expect((-2).positiveOrNil == nil)
    }

    @Test func positiveOrNilThroughOptionalChaining() {
        let some: Double? = 2
        let negative: Double? = -2
        let none: Double? = nil
        #expect(some?.positiveOrNil == 2)
        #expect(negative?.positiveOrNil == nil)
        #expect(none?.positiveOrNil == nil)
    }

    struct NonNegativeOrNil: Sendable, CustomTestStringConvertible {
        let name: String
        let value: Double
        let expected: Double?

        var testDescription: String {
            name
        }
    }

    @Test(arguments: [
        NonNegativeOrNil(name: "positive", value: 1.5, expected: 1.5),
        NonNegativeOrNil(name: "zero", value: 0.0, expected: 0.0),
        NonNegativeOrNil(name: "negative", value: -1.0, expected: nil),
        NonNegativeOrNil(name: "infinity", value: .infinity, expected: .infinity),
        NonNegativeOrNil(name: "negative infinity", value: -.infinity, expected: nil),
        NonNegativeOrNil(name: "NaN", value: .nan, expected: nil),
    ])
    func nonNegativeOrNilDouble(_ example: NonNegativeOrNil) {
        #expect(example.value.nonNegativeOrNil == example.expected)
    }

    @Test func clampedToRange() {
        #expect(1.5.clamped(to: 0.0 ... 1.0) == 1.0)
        #expect((-1.0).clamped(to: 0.0 ... 1.0) == 0.0)
        #expect(0.4.clamped(to: 0.0 ... 1.0) == 0.4)
    }
}
