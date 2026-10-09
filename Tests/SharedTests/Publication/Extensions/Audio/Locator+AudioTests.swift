//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import Testing

struct LocatorLocationsAudioTests {
    @Test("temporal is nil without a valid temporal fragment", arguments: [
        [],
        // Unrelated fragments
        ["page=5"],
        ["section", "start=10"],
        // Malformed fragments
        ["t=one"],
        ["t="],
        ["t"],
        ["t=10,"],
    ] as [[URLFragment]])
    func temporalIsNil(fragments: [URLFragment]) {
        #expect(Locator.Locations(fragments: fragments).temporal == nil)
    }

    @Test("temporal is parsed from the fragments", arguments: [
        // Position
        (["t=0"], TemporalSelector(position: 0)),
        (["t=71.5"], TemporalSelector(position: 71.5)),
        (["t=npt:0:02:00"], TemporalSelector(position: 120)),
        // Clip
        (["t=10,20"], TemporalSelector(start: 10, end: 20)),
        (["t=,20"], TemporalSelector(start: 0, end: 20)),
        (["t=1.1,1.5"], TemporalSelector(start: 1.1, end: 1.5)),
        // Compound fragment
        (["t=10&track=audio"], TemporalSelector(position: 10)),
        (["track=audio&t=10,20"], TemporalSelector(start: 10, end: 20)),
        // Other fragments are ignored
        (["page=3", "t=10", "section"], TemporalSelector(position: 10)),
        // The last valid temporal fragment wins
        (["t=5", "t=10"], TemporalSelector(position: 10)),
        (["t=5", "t=10", "t=one"], TemporalSelector(position: 10)),
        (["t=5&t=7", "page=2"], TemporalSelector(position: 7)),
    ] as [([URLFragment], TemporalSelector)])
    func temporal(fragments: [URLFragment], expected: TemporalSelector) {
        #expect(Locator.Locations(fragments: fragments).temporal == expected)
    }
}
