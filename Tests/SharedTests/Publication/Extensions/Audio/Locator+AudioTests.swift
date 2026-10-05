//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import Testing

struct LocatorLocationsAudioTests {
    private func position(_ time: Double) -> TemporalSelector {
        .position(TemporalPosition(time: time)!)
    }

    private func clip(_ start: Double, _ end: Double) -> TemporalSelector {
        .clip(TemporalClip(start: start, end: end)!)
    }

    @Test func temporalIsNilWhenNoFragments() {
        #expect(Locator.Locations().temporal == nil)
    }

    @Test func temporalIsNilForUnrelatedFragment() {
        #expect(Locator.Locations(fragments: ["page=5"]).temporal == nil)
        #expect(Locator.Locations(fragments: ["section", "start=10"]).temporal == nil)
    }

    @Test func temporalIsNilForMalformedFragment() {
        #expect(Locator.Locations(fragments: ["t=one"]).temporal == nil)
        #expect(Locator.Locations(fragments: ["t="]).temporal == nil)
        #expect(Locator.Locations(fragments: ["t"]).temporal == nil)
        #expect(Locator.Locations(fragments: ["t=10,"]).temporal == nil)
        #expect(Locator.Locations(fragments: [""]).temporal == nil)
    }

    @Test func temporalIsParsedFromPosition() {
        #expect(Locator.Locations(fragments: ["t=0"]).temporal == position(0))
        #expect(Locator.Locations(fragments: ["t=71.5"]).temporal == position(71.5))
        #expect(Locator.Locations(fragments: ["t=npt:0:02:00"]).temporal == position(120))
    }

    @Test func temporalIsParsedFromClip() {
        #expect(Locator.Locations(fragments: ["t=10,20"]).temporal == clip(10, 20))
        #expect(Locator.Locations(fragments: ["t=,20"]).temporal == clip(0, 20))
        #expect(Locator.Locations(fragments: ["t=1.1,1.5"]).temporal == clip(1.1, 1.5))
    }

    @Test func temporalIsParsedFromCompoundFragment() {
        #expect(Locator.Locations(fragments: ["t=10&track=audio"]).temporal == position(10))
        #expect(Locator.Locations(fragments: ["track=audio&t=10,20"]).temporal == clip(10, 20))
    }

    @Test func temporalIsParsedFromFragmentWithCharactersToEncode() {
        #expect(Locator.Locations(fragments: ["track=café noir&t=10"]).temporal == position(10))
        #expect(Locator.Locations(fragments: ["id=100%&t=10"]).temporal == position(10))
    }

    @Test func temporalIgnoresOtherFragments() {
        let locations = Locator.Locations(fragments: ["page=3", "t=10", "section"])
        #expect(locations.temporal == position(10))
    }

    @Test func temporalReturnsLastValidWhenMultipleFragments() {
        #expect(Locator.Locations(fragments: ["t=5", "t=10"]).temporal == position(10))
        #expect(Locator.Locations(fragments: ["t=5", "t=10", "t=one"]).temporal == position(10))
        #expect(Locator.Locations(fragments: ["t=5&t=7", "page=2"]).temporal == position(7))
    }
}
