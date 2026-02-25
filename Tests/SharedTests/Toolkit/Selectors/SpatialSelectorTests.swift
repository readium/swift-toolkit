//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import Testing

@Suite("SpatialSelector") struct SpatialSelectorTests {
    @Test("pixel default")
    func pixelDefault() {
        #expect(
            SpatialSelector(fragment: "xywh=10.0,20.0,100.0,50.0") ==
                SpatialSelector(x: 10, y: 20, width: 100, height: 50, unit: .pixel)
        )
    }

    @Test("explicit pixel unit")
    func explicitPixelUnit() {
        #expect(
            SpatialSelector(fragment: "xywh=pixel:10.0,20.0,100.0,50.0") ==
                SpatialSelector(x: 10, y: 20, width: 100, height: 50, unit: .pixel)
        )
    }

    @Test("percent unit")
    func percentUnit() {
        #expect(
            SpatialSelector(fragment: "xywh=percent:10.0,20.0,50.0,50.0") ==
                SpatialSelector(x: 10, y: 20, width: 50, height: 50, unit: .percent)
        )
    }

    @Test("invalid: missing xywh=")
    func invalidMissingPrefix() {
        #expect(SpatialSelector(fragment: "10,20,100,50") == nil)
    }

    @Test("invalid: wrong component count")
    func invalidWrongComponentCount() {
        #expect(SpatialSelector(fragment: "xywh=10,20,100") == nil)
    }

    @Test("fragment: pixel")
    func fragmentPixel() {
        #expect(SpatialSelector(x: 10, y: 20, width: 100, height: 50, unit: .pixel).fragment == "xywh=10.0,20.0,100.0,50.0")
    }

    @Test("fragment: percent")
    func fragmentPercent() {
        #expect(SpatialSelector(x: 10, y: 20, width: 50, height: 50, unit: .percent).fragment == "xywh=percent:10.0,20.0,50.0,50.0")
    }

    @Test("round-trip: pixel")
    func roundTripPixel() {
        let selector = SpatialSelector(x: 10, y: 20, width: 100, height: 50, unit: .pixel)
        #expect(SpatialSelector(fragment: selector.fragment) == selector)
    }

    @Test("round-trip: percent")
    func roundTripPercent() {
        let selector = SpatialSelector(x: 10, y: 20, width: 50, height: 50, unit: .percent)
        #expect(SpatialSelector(fragment: selector.fragment) == selector)
    }
}
