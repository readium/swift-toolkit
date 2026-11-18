//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumNavigator
import Testing

struct ProgressionStrategyTests {
    // The comments give the unrounded results.
    @Test("rounds the floating-point residue", arguments: [
        // (step, value, incremented, decremented)
        (0.1, 0.2, 0.3, 0.1), // 0.30000000000000004
        (0.1, 0.30000000000000004, 0.4, 0.2), // 0.20000000000000004 when decremented
        (0.1, 0.09999999999999998, 0.2, 0.0), // -2.7755575615628914e-17 when decremented
        (0.1, 0.123456, 0.22346, 0.02346), // 5 decimal places, not snapped to the steps
        (0.07, 0.1234567, 0.193457, 0.053457), // 6 decimal places
        (4.0, 12.000000000000002, 16.0, 8.0), // 8.000000000000002 when decremented
        (-0.1, 0.2, 0.1, 0.3), // 0.30000000000000004 when decremented
        (0.0, 0.2, 0.2, 0.2), // Zero step, NaN if rounded
    ])
    func roundsResidue(step: Double, value: Double, incremented: Double, decremented: Double) {
        let strategy = AnyProgressionStrategy.increment(step)
        // Compares the bit patterns to tell -0.0 from 0.0.
        #expect(strategy.increment(value).bitPattern == incremented.bitPattern)
        #expect(strategy.decrement(value).bitPattern == decremented.bitPattern)
    }

    @Test("rounds when created from generic code")
    func genericCode() {
        func strategy<Value: Numeric & Sendable>(_ increment: Value) -> AnyProgressionStrategy<Value> {
            .increment(increment)
        }
        #expect(strategy(Double(0.1)).increment(0.2) == 0.3)
    }

    @Test("leaves integers untouched")
    func integers() {
        let strategy = AnyProgressionStrategy.increment(2)
        #expect(strategy.increment(3) == 5)
        #expect(strategy.decrement(3) == 1)
    }
}
