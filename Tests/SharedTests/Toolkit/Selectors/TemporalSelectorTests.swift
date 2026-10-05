//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumShared
import Testing

struct TemporalSelectorTests {
    @Test("position: start only")
    func positionStartOnly() {
        #expect(TemporalSelector(fragment: "t=10.0") == .position(TemporalPosition(time: 10)))
    }

    @Test("clip: start and end")
    func clipStartAndEnd() {
        #expect(
            TemporalSelector(fragment: "t=10.0,20.0") ==
                .clip(TemporalClip(start: 10, end: 20))
        )
    }

    @Test("clip: end only")
    func clipEndOnly() {
        #expect(
            TemporalSelector(fragment: "t=,20.0") ==
                .clip(TemporalClip(start: nil, end: 20))
        )
    }

    @Test("npt: prefix stripped")
    func nptPrefixStripped() {
        #expect(
            TemporalSelector(fragment: "t=npt:10.0,20.0") ==
                .clip(TemporalClip(start: 10, end: 20))
        )
    }

    @Test("clip: start with trailing comma")
    func clipStartWithTrailingComma() {
        #expect(
            TemporalSelector(fragment: "t=10.0,") ==
                .clip(TemporalClip(start: 10, end: nil))
        )
    }

    @Test("invalid: missing t=")
    func invalidMissingT() {
        #expect(TemporalSelector(fragment: "10,20") == nil)
    }

    @Test("clock: MM:SS")
    func clockMMSS() {
        #expect(TemporalSelector(fragment: "t=1:30") == .position(TemporalPosition(time: 90)))
    }

    @Test("clock: HH:MM:SS")
    func clockHHMMSS() {
        #expect(TemporalSelector(fragment: "t=1:30:00") == .position(TemporalPosition(time: 5400)))
    }

    @Test("clock: npt: prefix with HH:MM:SS.sss")
    func clockNptPrefix() {
        #expect(
            TemporalSelector(fragment: "t=npt:0:01:30.5") ==
                .position(TemporalPosition(time: 90.5))
        )
    }

    @Test("clock: clip with MM:SS bounds")
    func clockClip() {
        #expect(
            TemporalSelector(fragment: "t=1:00,1:30") ==
                .clip(TemporalClip(start: 60, end: 90))
        )
    }

    @Test("invalid: seconds >= 60 in MM:SS")
    func invalidSecondsMMSS() {
        #expect(TemporalSelector(fragment: "t=1:60") == nil)
    }

    @Test("invalid: seconds >= 60 in HH:MM:SS")
    func invalidSecondsHHMMSS() {
        #expect(TemporalSelector(fragment: "t=1:30:60") == nil)
    }

    @Test("fragment: position")
    func fragmentPosition() {
        #expect(TemporalSelector.position(TemporalPosition(time: 10)).fragment == "t=10.0")
    }

    @Test("fragment: clip start and end")
    func fragmentClipStartAndEnd() {
        #expect(TemporalSelector.clip(TemporalClip(start: 10, end: 20)).fragment == "t=10.0,20.0")
    }

    @Test("fragment: clip start only")
    func fragmentClipStartOnly() {
        #expect(TemporalSelector.clip(TemporalClip(start: 10, end: nil)).fragment == "t=10.0,")
    }

    @Test("fragment: clip end only")
    func fragmentClipEndOnly() {
        #expect(TemporalSelector.clip(TemporalClip(start: nil, end: 20)).fragment == "t=,20.0")
    }

    @Test("round-trip: position")
    func roundTripPosition() {
        let selector = TemporalSelector.position(TemporalPosition(time: 10))
        #expect(TemporalSelector(fragment: selector.fragment) == selector)
    }

    @Test("round-trip: clip")
    func roundTripClip() {
        let selector = TemporalSelector.clip(TemporalClip(start: 10, end: 20))
        #expect(TemporalSelector(fragment: selector.fragment) == selector)
    }
}
